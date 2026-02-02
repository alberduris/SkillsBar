import Foundation

/// Discovers global MCP servers from ~/.claude.json top-level mcpServers
public struct GlobalMCPSource: Sendable {
    private static let logger = SkillsBarLog.logger(LogCategories.mcpDiscovery)

    /// Discover global MCP servers
    public static func discover() -> [MCPServer] {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            logger.debug("No ~/.claude.json found")
            return []
        }

        let servers = MCPConfigParser.parseGlobalServers(from: configURL)
        logger.debug("Global MCP discovery complete", metadata: ["count": "\(servers.count)"])
        return servers
    }
}
