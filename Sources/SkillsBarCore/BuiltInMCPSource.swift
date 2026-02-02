import Foundation

/// Discovers built-in MCP servers that Claude Code manages at runtime.
///
/// Built-in MCPs (scope "dynamic" in Claude Code) are not persisted in config files —
/// they are created in-process when Claude Code launches. We can only detect their
/// *availability* from user preferences, not their runtime connection status.
///
/// Currently known built-in MCPs:
/// - `claude-in-chrome`: Browser automation via Chrome extension (stdio, launched with --claude-in-chrome-mcp)
public struct BuiltInMCPSource: Sendable {
    private static let logger = SkillsBarLog.logger(LogCategories.mcpDiscovery)

    /// Discover built-in MCP servers based on user config
    public static func discover() -> [MCPServer] {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json")

        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return []
        }

        var servers: [MCPServer] = []

        // claude-in-chrome: enabled if claudeInChromeDefaultEnabled is true
        let chromeEnabled = MCPConfigParser.isClaudeInChromeEnabled(from: configURL)
        servers.append(MCPServer(
            id: "mcp:builtIn:claude-in-chrome",
            name: "claude-in-chrome",
            transport: .stdio,
            command: "claude",
            args: ["--claude-in-chrome-mcp"],
            source: .builtIn,
            isEnabled: chromeEnabled
        ))

        logger.debug("Built-in MCP discovery complete", metadata: [
            "count": "\(servers.count)",
            "chromeEnabled": "\(chromeEnabled)",
        ])
        return servers
    }
}
