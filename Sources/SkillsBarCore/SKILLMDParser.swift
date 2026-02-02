import Foundation
import Logging

/// Parser for SKILL.md files with YAML frontmatter
public struct SKILLMDParser: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.SKILLMDParser")

    /// Result of parsing a SKILL.md file
    public struct ParseResult: Sendable {
        public let name: String
        public let description: String
        public let metadata: SkillMetadata

        public init(name: String, description: String, metadata: SkillMetadata) {
            self.name = name
            self.description = description
            self.metadata = metadata
        }
    }

    /// Parse a SKILL.md file at the given URL
    public static func parse(at url: URL) throws -> ParseResult {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parse(content: content, fallbackName: url.deletingLastPathComponent().lastPathComponent)
    }

    /// Parse SKILL.md content
    public static func parse(content: String, fallbackName: String) throws -> ParseResult {
        // Check for YAML frontmatter (between --- delimiters)
        let lines = content.components(separatedBy: .newlines)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            // No frontmatter, use fallback values
            return ParseResult(
                name: fallbackName,
                description: extractDescription(from: content),
                metadata: SkillMetadata()
            )
        }

        // Find the closing ---
        var frontmatterEndIndex: Int?
        for (index, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = index + 1
                break
            }
        }

        guard let endIndex = frontmatterEndIndex else {
            // Unclosed frontmatter, treat as no frontmatter
            return ParseResult(
                name: fallbackName,
                description: extractDescription(from: content),
                metadata: SkillMetadata()
            )
        }

        // Extract frontmatter lines
        let frontmatterLines = Array(lines[1..<endIndex])
        let frontmatter = parseFrontmatter(lines: frontmatterLines)

        // Extract body content (after frontmatter)
        let bodyLines = Array(lines[(endIndex + 1)...])
        let bodyContent = bodyLines.joined(separator: "\n")

        // Get name from frontmatter or fallback
        let name = frontmatter.values["name"] ?? fallbackName

        // Get description from frontmatter or first paragraph of body
        let description = frontmatter.values["description"] ?? extractDescription(from: bodyContent)

        // Parse nested metadata object and merge with top-level for backward compatibility
        var customMetadata = frontmatter.nestedObjects["metadata"] ?? [:]

        // Backward compatibility: also check top-level author/version
        if customMetadata["author"] == nil, let author = frontmatter.values["author"] {
            customMetadata["author"] = author
        }
        if customMetadata["version"] == nil, let version = frontmatter.values["version"] {
            customMetadata["version"] = version
        }

        // Build metadata
        let metadata = SkillMetadata(
            license: frontmatter.values["license"],
            compatibility: frontmatter.values["compatibility"],
            customMetadata: customMetadata.isEmpty ? nil : customMetadata,
            allowedTools: parseStringArray(frontmatter.values["allowed-tools"] ?? frontmatter.values["allowed_tools"]),
            disableModelInvocation: parseBool(frontmatter.values["disable_model_invocation"]) ?? false,
            userInvocable: parseBool(frontmatter.values["user_invocable"]) ?? true
        )

        return ParseResult(name: name, description: description, metadata: metadata)
    }

    // MARK: - Private Helpers

    /// Result of parsing YAML frontmatter
    private struct FrontmatterResult {
        var values: [String: String] = [:]
        var nestedObjects: [String: [String: String]] = [:]
    }

    /// Parse YAML frontmatter into values and nested objects
    /// Supports block scalars (| and >) for multiline values
    /// Supports one level of nesting for objects like `metadata:`
    private static func parseFrontmatter(lines: [String]) -> FrontmatterResult {
        var result = FrontmatterResult()
        var currentKey: String?
        var currentValue: [String] = []
        var inBlockScalar = false
        var blockIndent: Int?

        // For nested object parsing
        var inNestedObject = false
        var nestedObjectKey: String?
        var nestedObjectIndent: Int?

        func saveCurrentKey() {
            if let key = currentKey {
                let value = currentValue.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    if inNestedObject, let objKey = nestedObjectKey {
                        result.nestedObjects[objKey, default: [:]][key] = value
                    } else {
                        result.values[key] = value
                    }
                }
            }
            currentKey = nil
            currentValue = []
            inBlockScalar = false
            blockIndent = nil
        }

        for line in lines {
            let lineIndent = line.prefix(while: { $0 == " " }).count

            // Check if we're exiting a nested object (line not indented enough)
            if inNestedObject, let objIndent = nestedObjectIndent {
                if lineIndent < objIndent && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    saveCurrentKey()
                    inNestedObject = false
                    nestedObjectKey = nil
                    nestedObjectIndent = nil
                }
            }

            // Check if this is a continuation of a block scalar
            if inBlockScalar {
                // First indented line sets the block indent
                if blockIndent == nil && lineIndent > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    blockIndent = lineIndent
                }

                // If we have a block indent and this line is at that level or deeper, it's part of the block
                if let indent = blockIndent, lineIndent >= indent {
                    currentValue.append(String(line.dropFirst(indent)).trimmingCharacters(in: .whitespaces))
                    continue
                } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Empty line in block - could be paragraph break, skip it
                    continue
                } else {
                    // Line is not indented enough, block scalar ends
                    saveCurrentKey()
                }
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Key: value parsing
            if let colonIndex = trimmed.firstIndex(of: ":") {
                // Save previous key if any
                saveCurrentKey()

                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                var value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)

                // Check for block scalar indicators
                if value == "|" || value == ">" || value == "|−" || value == ">-" {
                    currentKey = key
                    inBlockScalar = true
                    continue
                }

                // Check for nested object (empty value, not a block scalar)
                if value.isEmpty {
                    // This could be a nested object like `metadata:`
                    // Next indented lines will be its children
                    inNestedObject = true
                    nestedObjectKey = key
                    nestedObjectIndent = nil  // Will be set by first child line
                    continue
                }

                // Set nested object indent from first child
                if inNestedObject && nestedObjectIndent == nil && lineIndent > 0 {
                    nestedObjectIndent = lineIndent
                }

                // Remove quotes if present
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                } else if value.hasPrefix("'") && value.hasSuffix("'") {
                    value = String(value.dropFirst().dropLast())
                }

                if inNestedObject, let objKey = nestedObjectKey {
                    result.nestedObjects[objKey, default: [:]][key] = value
                } else {
                    result.values[key] = value
                }
            }
        }

        // Save final key if in block scalar
        saveCurrentKey()

        return result
    }

    /// Extract first non-empty paragraph as description
    private static func extractDescription(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var description = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines at the beginning
            if description.isEmpty && trimmed.isEmpty {
                continue
            }

            // Skip headers
            if trimmed.hasPrefix("#") {
                if description.isEmpty {
                    continue
                } else {
                    break
                }
            }

            // Empty line after content ends the paragraph
            if !description.isEmpty && trimmed.isEmpty {
                break
            }

            // Accumulate description
            if !description.isEmpty {
                description += " "
            }
            description += trimmed
        }

        // Truncate if too long
        let maxLength = 200
        if description.count > maxLength {
            description = String(description.prefix(maxLength - 3)) + "..."
        }

        return description
    }

    /// Parse a boolean value from string
    private static func parseBool(_ value: String?) -> Bool? {
        guard let value = value?.lowercased() else { return nil }
        switch value {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    /// Parse a comma-separated or YAML array into string array
    private static func parseStringArray(_ value: String?) -> [String]? {
        guard let value, !value.isEmpty else { return nil }

        // Handle YAML inline array: [item1, item2]
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let inner = String(value.dropFirst().dropLast())
            return inner.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }

        // Handle comma-separated
        return value.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
    }
}
