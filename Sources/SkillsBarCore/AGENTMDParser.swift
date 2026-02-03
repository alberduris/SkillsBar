import Foundation

/// Parser for agent .md files with YAML frontmatter
public struct AGENTMDParser: Sendable {
    /// Result of parsing an agent markdown file
    public struct ParseResult: Sendable {
        public let name: String
        public let description: String
        public let model: String?

        public init(name: String, description: String, model: String?) {
            self.name = name
            self.description = description
            self.model = model
        }
    }

    /// Parse an agent file at the given URL
    public static func parse(at url: URL) throws -> ParseResult {
        let content = try String(contentsOf: url, encoding: .utf8)
        let fallbackName = url.deletingPathExtension().lastPathComponent
        return try parse(content: content, fallbackName: fallbackName)
    }

    /// Parse agent markdown content
    public static func parse(content: String, fallbackName: String) throws -> ParseResult {
        let lines = content.components(separatedBy: .newlines)

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return ParseResult(
                name: fallbackName,
                description: extractDescription(from: content),
                model: nil
            )
        }

        var frontmatterEndIndex: Int?
        for (index, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterEndIndex = index + 1
                break
            }
        }

        guard let endIndex = frontmatterEndIndex else {
            return ParseResult(
                name: fallbackName,
                description: extractDescription(from: content),
                model: nil
            )
        }

        let frontmatterLines = Array(lines[1..<endIndex])
        let frontmatter = parseFrontmatter(lines: frontmatterLines)

        let bodyLines = Array(lines[(endIndex + 1)...])
        let bodyContent = bodyLines.joined(separator: "\n")

        let name = frontmatter["name"] ?? fallbackName
        let description = frontmatter["description"] ?? extractDescription(from: bodyContent)
        let model = frontmatter["model"]

        return ParseResult(name: name, description: description, model: model)
    }

    // MARK: - Private Helpers

    private static func parseFrontmatter(lines: [String]) -> [String: String] {
        var values: [String: String] = [:]
        var currentKey: String?
        var currentValue: [String] = []
        var inBlockScalar = false
        var blockIndent: Int?

        func saveCurrentKey() {
            if let key = currentKey {
                let value = currentValue.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    values[key] = value
                }
            }
            currentKey = nil
            currentValue = []
            inBlockScalar = false
            blockIndent = nil
        }

        for line in lines {
            let lineIndent = line.prefix(while: { $0 == " " }).count

            if inBlockScalar {
                if blockIndent == nil && lineIndent > 0 && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    blockIndent = lineIndent
                }

                if let indent = blockIndent, lineIndent >= indent {
                    currentValue.append(String(line.dropFirst(indent)).trimmingCharacters(in: .whitespaces))
                    continue
                } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                } else {
                    saveCurrentKey()
                }
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let colonIndex = trimmed.firstIndex(of: ":") {
                saveCurrentKey()

                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                var value = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)

                if value == "|" || value == ">" || value == "|−" || value == ">-" {
                    currentKey = key
                    inBlockScalar = true
                    continue
                }

                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                } else if value.hasPrefix("'") && value.hasSuffix("'") {
                    value = String(value.dropFirst().dropLast())
                }

                values[key] = value
            }
        }

        saveCurrentKey()
        return values
    }

    /// Extract first non-empty paragraph as description
    private static func extractDescription(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var description = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if description.isEmpty && trimmed.isEmpty {
                continue
            }

            if trimmed.hasPrefix("#") {
                if description.isEmpty {
                    continue
                } else {
                    break
                }
            }

            if !description.isEmpty && trimmed.isEmpty {
                break
            }

            if !description.isEmpty {
                description += " "
            }
            description += trimmed
        }

        let maxLength = 200
        if description.count > maxLength {
            description = String(description.prefix(maxLength - 3)) + "..."
        }

        return description
    }
}
