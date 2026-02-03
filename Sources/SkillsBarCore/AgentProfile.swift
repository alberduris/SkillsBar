import Foundation

/// Represents an installed agent profile (e.g., from a plugin)
public struct AgentProfile: Identifiable, Hashable, Sendable {
    /// Unique identifier (path-based)
    public let id: String

    /// Agent name (from frontmatter or filename)
    public let name: String

    /// Agent description (from frontmatter)
    public let description: String

    /// Preferred model (from frontmatter)
    public let model: String?

    /// Source type (global, plugin, project)
    public let source: SkillSource

    /// Path to the agent file
    public let path: URL

    /// Plugin name if source is .plugin
    public let pluginName: String?

    /// Marketplace name if source is .plugin (e.g., "claude-plugins-official")
    public let marketplaceName: String?

    /// Marketplace GitHub repo if source is .plugin (e.g., "user/repo")
    public let marketplaceRepo: String?

    /// Project root if source is .project
    public let projectRoot: URL?

    /// Plugin install scope (user/project/local) if source is .plugin
    public let pluginScope: Skill.PluginScope?

    /// Whether this agent's source (plugin) is enabled
    public let isEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        model: String?,
        source: SkillSource,
        path: URL,
        pluginName: String? = nil,
        marketplaceName: String? = nil,
        marketplaceRepo: String? = nil,
        projectRoot: URL? = nil,
        pluginScope: Skill.PluginScope? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.model = model
        self.source = source
        self.path = path
        self.pluginName = pluginName
        self.marketplaceName = marketplaceName
        self.marketplaceRepo = marketplaceRepo
        self.projectRoot = projectRoot
        self.pluginScope = pluginScope
        self.isEnabled = isEnabled
    }
}

// MARK: - Sorting

extension AgentProfile: Comparable {
    public static func < (lhs: AgentProfile, rhs: AgentProfile) -> Bool {
        if lhs.source.sortOrder != rhs.source.sortOrder {
            return lhs.source.sortOrder < rhs.source.sortOrder
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
