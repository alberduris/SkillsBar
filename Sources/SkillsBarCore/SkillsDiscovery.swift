import Foundation
import Logging

/// Main coordinator for discovering skills from all sources
public actor SkillsDiscovery {
    private let logger = Logger(label: "SkillsBarCore.SkillsDiscovery")

    /// Enabled agents for discovery
    public let enabledAgents: [Agent]

    /// Options for discovery
    public struct Options: Sendable {
        public var includeGlobal: Bool
        public var includePlugins: Bool
        public var includeProject: Bool
        public var projectPaths: [URL]

        public init(
            includeGlobal: Bool = true,
            includePlugins: Bool = true,
            includeProject: Bool = true,
            projectPaths: [URL] = []
        ) {
            self.includeGlobal = includeGlobal
            self.includePlugins = includePlugins
            self.includeProject = includeProject
            self.projectPaths = projectPaths
        }

        /// Default options with all sources enabled
        public static let all = Options()

        /// Options for only global skills
        public static let globalOnly = Options(
            includeGlobal: true,
            includePlugins: false,
            includeProject: false
        )

        /// Options for only project skills
        public static func projectOnly(at paths: [URL]) -> Options {
            Options(
                includeGlobal: false,
                includePlugins: false,
                includeProject: true,
                projectPaths: paths
            )
        }

        /// Options for only project skills at a single path
        public static func projectOnly(at path: URL) -> Options {
            projectOnly(at: [path])
        }
    }

    /// Initialize with enabled agents (defaults to supported agents)
    public init(enabledAgents: [Agent] = AgentRegistry.supported) {
        self.enabledAgents = enabledAgents
    }

    /// Discover all skills from all enabled agents
    public func discoverAll(options: Options = .all) async -> [Skill] {
        var allSkills: [Skill] = []

        for agent in enabledAgents {
            let agentSkills = await discover(for: agent, options: options)
            allSkills.append(contentsOf: agentSkills)
        }

        return allSkills.sorted()
    }

    /// Discover skills for a specific agent
    public func discover(for agent: Agent, options: Options = .all) async -> [Skill] {
        logger.info("Discovering skills", metadata: [
            "agent": "\(agent.id)",
            "global": "\(options.includeGlobal)",
            "plugins": "\(options.includePlugins)",
            "project": "\(options.includeProject)",
        ])

        var skills: [Skill] = []

        // Discover from each source concurrently
        await withTaskGroup(of: [Skill].self) { group in
            if options.includeGlobal {
                group.addTask {
                    await GlobalSkillsSource.discover(for: agent)
                }
            }

            if options.includePlugins && agent.supportsPlugins {
                group.addTask {
                    await PluginSkillsSource.discover(for: agent)
                }
            }

            if options.includeProject {
                for projectPath in options.projectPaths {
                    group.addTask {
                        await ProjectSkillsSource.discover(for: agent, at: projectPath)
                    }
                }
            }

            for await sourceSkills in group {
                skills.append(contentsOf: sourceSkills)
            }
        }

        logger.info("Discovery complete", metadata: [
            "agent": "\(agent.id)",
            "totalSkills": "\(skills.count)",
        ])

        return skills.sorted()
    }

    /// Discover only global skills for all enabled agents
    public func discoverGlobal() async -> [Skill] {
        await discoverAll(options: .globalOnly)
    }

    /// Discover only plugin skills for all enabled agents
    public func discoverPlugins() async -> [Skill] {
        let options = Options(
            includeGlobal: false,
            includePlugins: true,
            includeProject: false
        )
        return await discoverAll(options: options)
    }

    /// Discover only project skills at specific paths
    public func discoverProject(at paths: [URL]) async -> [Skill] {
        await discoverAll(options: .projectOnly(at: paths))
    }

    /// Discover only project skills at a specific path
    public func discoverProject(at path: URL) async -> [Skill] {
        await discoverProject(at: [path])
    }
}

// MARK: - Convenience Extensions

extension SkillsDiscovery {
    /// Create a discovery instance for the default agent (Claude Code)
    public static func forClaudeCode() -> SkillsDiscovery {
        SkillsDiscovery(enabledAgents: [AgentRegistry.defaultAgent])
    }

    /// Create a discovery instance for all supported agents
    public static func forAllSupported() -> SkillsDiscovery {
        SkillsDiscovery(enabledAgents: AgentRegistry.supported)
    }
}
