import Foundation
import Logging

/// Main coordinator for discovering agent profiles
public actor AgentsDiscovery {
    private let logger = Logger(label: "SkillsBarCore.AgentsDiscovery")

    /// Options for agent discovery
    public struct Options: Sendable {
        public var includeGlobal: Bool
        public var includeProject: Bool
        public var projectPaths: [URL]

        public init(
            includeGlobal: Bool = true,
            includeProject: Bool = true,
            projectPaths: [URL] = []
        ) {
            self.includeGlobal = includeGlobal
            self.includeProject = includeProject
            self.projectPaths = projectPaths
        }

        public static let all = Options()
    }

    public init() {}

    /// Discover all agent profiles
    public func discoverAll(options: Options = .all) async -> [AgentProfile] {
        logger.info("Discovering agent profiles", metadata: [
            "global": "\(options.includeGlobal)",
            "project": "\(options.includeProject)",
        ])

        let agents = await PluginAgentsSource.discover(
            includeGlobal: options.includeGlobal,
            includeProject: options.includeProject,
            projectPaths: options.projectPaths
        )

        logger.info("Agent discovery complete", metadata: ["totalAgents": "\(agents.count)"])
        return agents.sorted()
    }
}
