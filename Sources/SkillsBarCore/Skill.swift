import Foundation

/// Metadata extracted from SKILL.md frontmatter
public struct SkillMetadata: Sendable, Codable, Equatable {
    /// License for the skill (e.g., "Apache-2.0", "MIT")
    public let license: String?

    /// Environment requirements (e.g., "Requires git, docker, and internet access")
    public let compatibility: String?

    /// Arbitrary key-value pairs from the `metadata:` object in frontmatter
    /// Per spec: author, version, and any custom fields go here
    public let customMetadata: [String: String]?

    /// Pre-approved tools the skill may use (experimental, per spec)
    public let allowedTools: [String]?

    // MARK: - SkillsBar Extensions (not in official spec)

    /// When true, skill cannot be invoked directly by the model
    public let disableModelInvocation: Bool

    /// When false, skill cannot be invoked via /skillname
    public let userInvocable: Bool

    public init(
        license: String? = nil,
        compatibility: String? = nil,
        customMetadata: [String: String]? = nil,
        allowedTools: [String]? = nil,
        disableModelInvocation: Bool = false,
        userInvocable: Bool = true
    ) {
        self.license = license
        self.compatibility = compatibility
        self.customMetadata = customMetadata
        self.allowedTools = allowedTools
        self.disableModelInvocation = disableModelInvocation
        self.userInvocable = userInvocable
    }

    // MARK: - Convenience Accessors for common metadata fields

    /// Author from metadata object (convenience accessor)
    public var author: String? {
        customMetadata?["author"]
    }

    /// Version from metadata object (convenience accessor)
    public var version: String? {
        customMetadata?["version"]
    }
}

/// Represents a skill for an AI coding agent
public struct Skill: Identifiable, Hashable, Sendable {
    /// Install scope for plugin skills
    public enum PluginScope: String, Sendable, Codable, CaseIterable {
        case user
        case project
        case local
    }

    /// Unique identifier (path-based)
    public let id: String

    /// Skill name (from frontmatter or directory name)
    public let name: String

    /// Skill description (from frontmatter)
    public let description: String

    /// Agent this skill belongs to
    public let agent: Agent

    /// Source type (global, plugin, project)
    public let source: SkillSource

    /// Path to the skill directory
    public let path: URL

    /// Plugin name if source is .plugin
    public let pluginName: String?

    /// Marketplace name if source is .plugin (e.g., "claude-plugins-official")
    public let marketplaceName: String?

    /// Marketplace GitHub repo if source is .plugin (e.g., "anthropics/claude-code")
    public let marketplaceRepo: String?

    /// Project root if source is .project
    public let projectRoot: URL?

    /// Plugin install scope (user/project/local) if source is .plugin
    public let pluginScope: PluginScope?

    /// Additional metadata from SKILL.md
    public let metadata: SkillMetadata?

    /// Whether the skill's source (plugin) is enabled
    /// Always true for global and project skills
    /// For plugin skills, reflects the plugin's enabled status in settings.json
    public let isEnabled: Bool

    public init(
        id: String,
        name: String,
        description: String,
        agent: Agent,
        source: SkillSource,
        path: URL,
        pluginName: String? = nil,
        marketplaceName: String? = nil,
        marketplaceRepo: String? = nil,
        projectRoot: URL? = nil,
        pluginScope: PluginScope? = nil,
        metadata: SkillMetadata? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.agent = agent
        self.source = source
        self.path = path
        self.pluginName = pluginName
        self.marketplaceName = marketplaceName
        self.marketplaceRepo = marketplaceRepo
        self.projectRoot = projectRoot
        self.pluginScope = pluginScope
        self.metadata = metadata
        self.isEnabled = isEnabled
    }

    // MARK: - Hashable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Computed Properties

    /// Path to the SKILL.md file
    public var skillFilePath: URL {
        path.appendingPathComponent(agent.skillFileName)
    }

    /// Whether this skill can be invoked by the user (e.g., via /skillname)
    public var isUserInvocable: Bool {
        metadata?.userInvocable ?? true
    }

    /// Display label combining source and name
    public var displayLabel: String {
        if let pluginName {
            return "\(pluginName)/\(name)"
        }
        return name
    }
}

// MARK: - Sorting

extension Skill: Comparable {
    public static func < (lhs: Skill, rhs: Skill) -> Bool {
        // Sort by source first, then by name
        if lhs.source.sortOrder != rhs.source.sortOrder {
            return lhs.source.sortOrder < rhs.source.sortOrder
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
