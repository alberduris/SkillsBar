import Foundation

/// Discovers project-specific MCP servers from ~/.claude.json project entries and .mcp.json files
public struct ProjectMCPSource: Sendable {
    private static let logger = SkillsBarLog.logger(LogCategories.mcpDiscovery)

    /// Discover project MCP servers from both ~/.claude.json project entries and .mcp.json files
    public static func discover(at projectPaths: [URL]) -> [MCPServer] {
        guard !projectPaths.isEmpty else { return [] }

        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")

        var allServers: [MCPServer] = []

        // 1. Parse per-project servers from ~/.claude.json
        if FileManager.default.fileExists(atPath: configURL.path) {
            let projectServers = MCPConfigParser.parseProjectServers(
                from: configURL, projectPaths: projectPaths)
            allServers.append(contentsOf: projectServers)
        }

        // 2. Parse .mcp.json files at each project root
        for projectPath in projectPaths {
            let mcpJsonURL = projectPath.appendingPathComponent(".mcp.json")
            guard FileManager.default.fileExists(atPath: mcpJsonURL.path) else { continue }

            // Read disabled .mcp.json server names from ~/.claude.json
            let disabledNames: Set<String>
            if FileManager.default.fileExists(atPath: configURL.path) {
                disabledNames = MCPConfigParser.readDisabledMcpJsonServers(
                    from: configURL, projectPath: projectPath)
            } else {
                disabledNames = []
            }

            let mcpJsonServers = MCPConfigParser.parseMcpJsonFile(
                at: projectPath, disabledNames: disabledNames)

            // Only add servers from .mcp.json that aren't already from ~/.claude.json
            let existingIDs = Set(allServers.map(\.id))
            for server in mcpJsonServers where !existingIDs.contains(server.id) {
                allServers.append(server)
            }
        }

        logger.debug("Project MCP discovery complete", metadata: [
            "count": "\(allServers.count)",
            "projects": "\(projectPaths.count)",
        ])
        return allServers.sorted()
    }
}
