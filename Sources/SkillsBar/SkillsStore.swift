import Foundation
import SkillsBarCore

/// Main observable store for skills in the UI
@MainActor @Observable
public final class SkillsStore {
    // MARK: - State

    /// All discovered skills
    public private(set) var skills: [Skill] = []

    /// Skills grouped by source
    public var skillsBySource: [SkillSource: [Skill]] {
        Dictionary(grouping: skills, by: \.source)
    }

    /// Skills grouped by agent
    public var skillsByAgent: [Agent: [Skill]] {
        Dictionary(grouping: skills, by: \.agent)
    }

    /// Whether a refresh is in progress
    public private(set) var isRefreshing = false

    /// Last refresh timestamp
    public private(set) var lastRefreshTime: Date?

    /// Current project paths for project skills discovery
    public var projectPaths: [URL] = [] {
        didSet {
            if projectPaths != oldValue {
                Task { await refresh() }
            }
        }
    }

    /// Recursive project paths (repos folders) that auto-scan subfolders
    public var recursiveProjectPaths: [URL] = [] {
        didSet {
            if recursiveProjectPaths != oldValue {
                Task { await refresh() }
            }
        }
    }

    // MARK: - Private State

    private var discovery: SkillsDiscovery

    /// Enabled agents for discovery
    public var enabledAgents: [Agent] = AgentRegistry.supported {
        didSet {
            if enabledAgents.map(\.id) != oldValue.map(\.id) {
                discovery = SkillsDiscovery(enabledAgents: enabledAgents)
                Task { await refresh() }
            }
        }
    }

    // MARK: - Computed Properties

    /// Total number of skills
    public var totalCount: Int { skills.count }

    /// Count of global skills
    public var globalCount: Int { skillsBySource[.global]?.count ?? 0 }

    /// Count of plugin skills
    public var pluginCount: Int { skillsBySource[.plugin]?.count ?? 0 }

    /// Count of project skills
    public var projectCount: Int { skillsBySource[.project]?.count ?? 0 }

    /// Whether there are any skills
    public var hasSkills: Bool { !skills.isEmpty }

    /// User-invocable skills only
    public var userInvocableSkills: [Skill] {
        skills.filter { $0.isUserInvocable }
    }

    // MARK: - Initialization

    public init(enabledAgents: [Agent] = AgentRegistry.supported) {
        self.discovery = SkillsDiscovery(enabledAgents: enabledAgents)
    }

    // MARK: - Actions

    /// Refresh all skills
    public func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true

        // Expand recursive paths and combine with direct project paths
        let expandedPaths = RecursivePathExpander.expand(recursiveProjectPaths)
        let allProjectPaths = Array(Set(projectPaths + expandedPaths))

        let options = SkillsDiscovery.Options(
            includeGlobal: true,
            includePlugins: true,
            includeProject: !allProjectPaths.isEmpty,
            projectPaths: allProjectPaths
        )

        let discoveredSkills = await discovery.discoverAll(options: options)
        skills = discoveredSkills
        lastRefreshTime = Date()

        isRefreshing = false
    }

    /// Add a project path
    public func addProjectPath(_ path: URL) {
        if !projectPaths.contains(path) {
            projectPaths.append(path)
        }
    }

    /// Remove a project path
    public func removeProjectPath(_ path: URL) {
        projectPaths.removeAll { $0 == path }
    }

    /// Clear all project paths
    public func clearProjectPaths() {
        projectPaths = []
    }

    /// Add a recursive project path (repos folder)
    public func addRecursiveProjectPath(_ path: URL) {
        if !recursiveProjectPaths.contains(path) {
            recursiveProjectPaths.append(path)
        }
    }

    /// Remove a recursive project path
    public func removeRecursiveProjectPath(_ path: URL) {
        recursiveProjectPaths.removeAll { $0 == path }
    }

    /// Clear all recursive project paths
    public func clearRecursiveProjectPaths() {
        recursiveProjectPaths = []
    }

    /// Clear all skills
    public func clear() {
        skills = []
        lastRefreshTime = nil
    }

    /// Find a skill by ID
    public func skill(withID id: String) -> Skill? {
        skills.first { $0.id == id }
    }

    /// Find skills by name (partial match)
    public func skills(matching query: String) -> [Skill] {
        guard !query.isEmpty else { return skills }
        let lowercasedQuery = query.lowercased()
        return skills.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.description.lowercased().contains(lowercasedQuery)
        }
    }
}

// MARK: - Singleton Access

extension SkillsStore {
    /// Shared instance for app-wide access
    public static let shared = SkillsStore()
}
