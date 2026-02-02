import Foundation

/// Parses MCP server configurations from Claude config files
public struct MCPConfigParser: Sendable {
    private static let logger = SkillsBarLog.logger(LogCategories.mcpConfig)

    // MARK: - Internal Codable Types

    /// Raw server entry as it appears in JSON
    struct RawServerEntry: Codable {
        let type: String?
        let url: String?
        let command: String?
        let args: [String]?
        let env: [String: String]?
        let headers: [String: String]?
    }

    /// Per-project entry in ~/.claude.json projects dict
    struct ProjectEntry: Codable {
        let mcpServers: [String: RawServerEntry]?
        let disabledMcpServers: [String]?
        let disabledMcpjsonServers: [String]?
    }

    /// Top-level ~/.claude.json structure (only what we need)
    struct GlobalConfig: Codable {
        let mcpServers: [String: RawServerEntry]?
        let projects: [String: ProjectEntry]?
        let claudeInChromeDefaultEnabled: Bool?
    }

    // MARK: - Public API

    /// Parse global MCP servers from ~/.claude.json top-level mcpServers
    public static func parseGlobalServers(from configURL: URL) -> [MCPServer] {
        guard let data = try? Data(contentsOf: configURL) else {
            logger.debug("Could not read config file", metadata: ["path": configURL.path])
            return []
        }

        guard let config = try? JSONDecoder().decode(GlobalConfig.self, from: data) else {
            logger.warning("Failed to decode config file", metadata: ["path": configURL.path])
            return []
        }

        guard let servers = config.mcpServers, !servers.isEmpty else {
            return []
        }

        var result: [MCPServer] = []
        for (name, entry) in servers {
            if let server = makeServer(
                name: name, rawEntry: entry, source: .global, projectName: nil, isEnabled: true
            ) {
                result.append(server)
            }
        }

        logger.debug("Parsed global servers", metadata: ["count": "\(result.count)"])
        return result.sorted()
    }

    /// Parse per-project MCP servers from ~/.claude.json project entries
    public static func parseProjectServers(from claudeJsonURL: URL, projectPaths: [URL]) -> [MCPServer] {
        guard let data = try? Data(contentsOf: claudeJsonURL) else {
            logger.debug("Could not read config file", metadata: ["path": claudeJsonURL.path])
            return []
        }

        // Use JSONSerialization to extract per-project entries
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any] else {
            return []
        }

        var result: [MCPServer] = []
        let projectPathStrings = Set(projectPaths.map(\.path))

        for (projectPath, projectValue) in projects {
            guard projectPathStrings.contains(projectPath),
                  let projectData = try? JSONSerialization.data(withJSONObject: projectValue),
                  let entry = try? JSONDecoder().decode(ProjectEntry.self, from: projectData) else {
                continue
            }

            let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
            let disabledSet = Set(entry.disabledMcpServers ?? [])

            guard let servers = entry.mcpServers else { continue }

            for (name, rawEntry) in servers {
                if let server = makeServer(
                    name: name,
                    rawEntry: rawEntry,
                    source: .project,
                    projectName: projectName,
                    isEnabled: !disabledSet.contains(name)
                ) {
                    result.append(server)
                }
            }
        }

        logger.debug("Parsed project servers", metadata: [
            "count": "\(result.count)",
            "projects": "\(projectPaths.count)",
        ])
        return result.sorted()
    }

    /// Parse .mcp.json file at a project root
    public static func parseMcpJsonFile(at projectRoot: URL, disabledNames: Set<String>) -> [MCPServer] {
        let mcpJsonURL = projectRoot.appendingPathComponent(".mcp.json")

        guard let data = try? Data(contentsOf: mcpJsonURL) else {
            return []
        }

        struct MCPJsonFile: Codable {
            let mcpServers: [String: RawServerEntry]?
        }

        guard let file = try? JSONDecoder().decode(MCPJsonFile.self, from: data),
              let servers = file.mcpServers, !servers.isEmpty else {
            return []
        }

        let projectName = projectRoot.lastPathComponent
        var result: [MCPServer] = []

        for (name, rawEntry) in servers {
            if let server = makeServer(
                name: name,
                rawEntry: rawEntry,
                source: .project,
                projectName: projectName,
                isEnabled: !disabledNames.contains(name)
            ) {
                result.append(server)
            }
        }

        logger.debug("Parsed .mcp.json", metadata: [
            "project": projectName,
            "count": "\(result.count)",
        ])
        return result.sorted()
    }

    // MARK: - Internal Helpers

    /// Build an MCPServer from a raw JSON entry, resolving transport
    static func makeServer(
        name: String,
        rawEntry: RawServerEntry,
        source: MCPSource,
        projectName: String?,
        isEnabled: Bool
    ) -> MCPServer? {
        // Resolve transport: explicit type > infer from command (stdio) > infer from url (http)
        let transport: MCPTransport
        if let typeStr = rawEntry.type, let t = MCPTransport(rawValue: typeStr) {
            transport = t
        } else if rawEntry.command != nil {
            transport = .stdio
        } else if rawEntry.url != nil {
            transport = .http
        } else {
            logger.warning("Cannot determine transport for server", metadata: ["name": name])
            return nil
        }

        // Build ID
        var idParts = ["mcp", source.rawValue]
        if let projectName {
            idParts.append(projectName)
        }
        idParts.append(name)
        let id = idParts.joined(separator: ":")

        // Extract env/header key names only (values are secrets)
        let envKeys = rawEntry.env.map { Array($0.keys).sorted() } ?? []
        let headerKeys = rawEntry.headers.map { Array($0.keys).sorted() } ?? []

        return MCPServer(
            id: id,
            name: name,
            transport: transport,
            url: rawEntry.url,
            command: rawEntry.command,
            args: rawEntry.args ?? [],
            envKeys: envKeys,
            headerKeys: headerKeys,
            source: source,
            projectName: projectName,
            isEnabled: isEnabled
        )
    }

    /// Check if Claude in Chrome is enabled by default in ~/.claude.json
    public static func isClaudeInChromeEnabled(from configURL: URL) -> Bool {
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(GlobalConfig.self, from: data) else {
            return false
        }
        return config.claudeInChromeDefaultEnabled ?? false
    }

    /// Read disabled .mcp.json server names for a project path from ~/.claude.json
    public static func readDisabledMcpJsonServers(from claudeJsonURL: URL, projectPath: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: claudeJsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = json["projects"] as? [String: Any],
              let projectValue = projects[projectPath.path],
              let projectData = try? JSONSerialization.data(withJSONObject: projectValue),
              let entry = try? JSONDecoder().decode(ProjectEntry.self, from: projectData) else {
            return []
        }
        return Set(entry.disabledMcpjsonServers ?? [])
    }
}
