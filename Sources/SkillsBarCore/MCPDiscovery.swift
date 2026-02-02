import Foundation

/// Main coordinator for discovering MCP servers from all sources
public actor MCPDiscovery {
    private let logger = SkillsBarLog.logger(LogCategories.mcpDiscovery)

    /// Options for MCP discovery
    public struct Options: Sendable {
        public var includeGlobal: Bool
        public var includeProject: Bool
        public var includeBuiltIn: Bool
        public var projectPaths: [URL]

        public init(
            includeGlobal: Bool = true,
            includeProject: Bool = true,
            includeBuiltIn: Bool = true,
            projectPaths: [URL] = []
        ) {
            self.includeGlobal = includeGlobal
            self.includeProject = includeProject
            self.includeBuiltIn = includeBuiltIn
            self.projectPaths = projectPaths
        }

        /// Default options with all sources enabled
        public static let all = Options()

        /// Options for only global MCPs
        public static let globalOnly = Options(
            includeGlobal: true,
            includeProject: false,
            includeBuiltIn: false
        )

        /// Options for only project MCPs
        public static func projectOnly(at paths: [URL]) -> Options {
            Options(
                includeGlobal: false,
                includeProject: true,
                includeBuiltIn: false,
                projectPaths: paths
            )
        }
    }

    public init() {}

    /// Discover all MCP servers from configured sources
    public func discoverAll(options: Options = .all) async -> [MCPServer] {
        logger.info("Discovering MCP servers", metadata: [
            "global": "\(options.includeGlobal)",
            "project": "\(options.includeProject)",
        ])

        var servers: [MCPServer] = []

        await withTaskGroup(of: [MCPServer].self) { group in
            if options.includeGlobal {
                group.addTask {
                    GlobalMCPSource.discover()
                }
            }

            if options.includeProject && !options.projectPaths.isEmpty {
                group.addTask {
                    ProjectMCPSource.discover(at: options.projectPaths)
                }
            }

            if options.includeBuiltIn {
                group.addTask {
                    BuiltInMCPSource.discover()
                }
            }

            for await sourceServers in group {
                servers.append(contentsOf: sourceServers)
            }
        }

        logger.info("MCP discovery complete", metadata: ["totalServers": "\(servers.count)"])
        return servers.sorted()
    }
}
