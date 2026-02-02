import Foundation

/// Transport protocol for an MCP server
public enum MCPTransport: String, Sendable, Codable {
    case http
    case sse
    case stdio

    /// Human-readable description
    public var description: String {
        switch self {
        case .http: return "HTTP"
        case .sse: return "SSE"
        case .stdio: return "stdio"
        }
    }
}

/// Source type for an MCP server configuration
public enum MCPSource: String, Sendable, CaseIterable, Codable {
    /// Global MCP servers from top-level mcpServers in ~/.claude.json
    case global

    /// Project-specific MCP servers from per-project entries in ~/.claude.json or .mcp.json
    case project

    /// Built-in MCPs managed by Claude Code at runtime (e.g., claude-in-chrome)
    case builtIn = "builtIn"

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .project:
            return "Project"
        case .builtIn:
            return "Built-in"
        }
    }

    /// SF Symbol name for UI
    public var sfSymbolName: String {
        switch self {
        case .global:
            return "globe"
        case .project:
            return "folder"
        case .builtIn:
            return "shippingbox"
        }
    }

    /// Sort order for display (project first, then global, then built-in)
    public var sortOrder: Int {
        switch self {
        case .project:
            return 0
        case .global:
            return 1
        case .builtIn:
            return 2
        }
    }
}

/// Represents an MCP server configuration
public struct MCPServer: Identifiable, Hashable, Sendable {
    /// Unique identifier (e.g., "mcp:global:context7", "mcp:project:lairdmates:vercel")
    public let id: String

    /// Server name (the key in mcpServers dict)
    public let name: String

    /// Transport protocol
    public let transport: MCPTransport

    /// URL for http/sse transports
    public let url: String?

    /// Command for stdio transport
    public let command: String?

    /// Arguments for stdio transport
    public let args: [String]

    /// Environment variable key names (values are secrets, not stored)
    public let envKeys: [String]

    /// Header key names (values are secrets, not stored)
    public let headerKeys: [String]

    /// Source type (global or project)
    public let source: MCPSource

    /// Project name (last path component) when source is .project
    public let projectName: String?

    /// Whether this server is enabled
    public let isEnabled: Bool

    public init(
        id: String,
        name: String,
        transport: MCPTransport,
        url: String? = nil,
        command: String? = nil,
        args: [String] = [],
        envKeys: [String] = [],
        headerKeys: [String] = [],
        source: MCPSource,
        projectName: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.transport = transport
        self.url = url
        self.command = command
        self.args = args
        self.envKeys = envKeys
        self.headerKeys = headerKeys
        self.source = source
        self.projectName = projectName
        self.isEnabled = isEnabled
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: MCPServer, rhs: MCPServer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sorting

extension MCPServer: Comparable {
    public static func < (lhs: MCPServer, rhs: MCPServer) -> Bool {
        if lhs.source.sortOrder != rhs.source.sortOrder {
            return lhs.source.sortOrder < rhs.source.sortOrder
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
