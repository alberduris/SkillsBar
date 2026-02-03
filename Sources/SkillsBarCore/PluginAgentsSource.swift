import Foundation
import Logging

/// Discovers agent profiles from installed Claude Code plugins
public struct PluginAgentsSource: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.PluginAgentsSource")

    struct InstalledPluginsFile: Codable {
        let version: Int?
        let plugins: [String: [InstalledPluginEntry]]?
    }

    struct InstalledPluginEntry: Codable {
        let scope: Skill.PluginScope
        let installPath: String
        let projectPath: String?
        let lastUpdated: String?
    }

    struct PluginInstallInfo: Sendable {
        let pluginKey: String
        let pluginName: String
        let marketplaceName: String
        let scope: Skill.PluginScope
        let installPath: String
        let projectPath: URL?
        let lastUpdated: Date?
        let isEnabled: Bool
    }

    /// Discover agent profiles for an agent (Claude Code)
    public static func discover(
        for agent: Agent = AgentRegistry.defaultAgent,
        includeGlobal: Bool,
        includeProject: Bool,
        projectPaths: [URL]
    ) async -> [AgentProfile] {
        guard agent.supportsPlugins else {
            return []
        }

        guard let pluginsPath = agent.pluginsPath,
              FileManager.default.fileExists(atPath: pluginsPath.path) else {
            return []
        }

        let enabledPlugins = readEnabledPlugins(from: agent.settingsPath)
        let installedPluginsPath = pluginsPath.appendingPathComponent("installed_plugins.json")
        let installInfoByPath = readInstalledPlugins(
            from: installedPluginsPath,
            globalEnabled: enabledPlugins)

        let marketplaceRepos = readMarketplaceRepos(from: agent.knownMarketplacesPath)
        let projectPathSet = Set(projectPaths.map { $0.standardizedFileURL.path })

        var agents: [AgentProfile] = []

        for info in installInfoByPath.values {
            let source: SkillSource
            switch info.scope {
            case .user:
                guard includeGlobal else { continue }
                source = .global
            case .project, .local:
                guard includeProject else { continue }
                guard let projectPath = info.projectPath?.standardizedFileURL.path,
                      projectPathSet.contains(projectPath) else {
                    continue
                }
                source = .project
            }

            let installURL = URL(fileURLWithPath: info.installPath)
            let agentsURL = installURL.appendingPathComponent("agents")
            guard FileManager.default.fileExists(atPath: agentsURL.path) else { continue }

            let marketplaceRepo = marketplaceRepos[info.marketplaceName]

            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: agentsURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for fileURL in contents where fileURL.pathExtension.lowercased() == "md" {
                    do {
                        let parseResult = try AGENTMDParser.parse(at: fileURL)

                        let agentProfile = AgentProfile(
                            id: makeAgentID(
                                source: source,
                                pluginName: info.pluginName,
                                marketplaceName: info.marketplaceName,
                                projectRoot: info.projectPath,
                                path: fileURL,
                                pluginScope: info.scope),
                            name: parseResult.name,
                            description: parseResult.description,
                            model: parseResult.model,
                            source: source,
                            path: fileURL,
                            pluginName: info.pluginName,
                            marketplaceName: info.marketplaceName,
                            marketplaceRepo: marketplaceRepo,
                            projectRoot: info.projectPath,
                            pluginScope: info.scope,
                            isEnabled: info.isEnabled
                        )

                        agents.append(agentProfile)
                    } catch {
                        logger.warning("Failed to parse agent file", metadata: [
                            "path": "\(fileURL.path)",
                            "error": "\(error.localizedDescription)",
                        ])
                    }
                }
            } catch {
                logger.warning("Failed to read agents directory", metadata: [
                    "path": "\(agentsURL.path)",
                    "error": "\(error.localizedDescription)",
                ])
            }
        }

        return agents.sorted()
    }

    // MARK: - Helpers

    private static func makeAgentID(
        source: SkillSource,
        pluginName: String?,
        marketplaceName: String?,
        projectRoot: URL?,
        path: URL,
        pluginScope: Skill.PluginScope?
    ) -> String {
        var components = ["agent", source.rawValue]
        if let marketplaceName {
            components.append(marketplaceName)
        }
        if let pluginName {
            components.append(pluginName)
        }
        if let pluginScope {
            components.append(pluginScope.rawValue)
        }
        if let projectRoot {
            components.append(projectRoot.standardizedFileURL.path)
        }
        components.append(path.lastPathComponent)
        return components.joined(separator: ":")
    }

    // MARK: - Installed Plugin Metadata

    private static func readEnabledPlugins(from settingsPath: URL?) -> [String: Bool] {
        guard let settingsPath,
              FileManager.default.fileExists(atPath: settingsPath.path) else {
            return [:]
        }

        struct ClaudeSettings: Codable {
            let enabledPlugins: [String: Bool]?
        }

        do {
            let data = try Data(contentsOf: settingsPath)
            let settings = try JSONDecoder().decode(ClaudeSettings.self, from: data)
            return settings.enabledPlugins ?? [:]
        } catch {
            logger.warning("Failed to parse plugin settings", metadata: [
                "path": "\(settingsPath.path)",
                "error": "\(error.localizedDescription)",
            ])
            return [:]
        }
    }

    private static func readInstalledPlugins(
        from path: URL,
        globalEnabled: [String: Bool]
    ) -> [String: PluginInstallInfo] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return [:]
        }

        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: path),
              let file = try? decoder.decode(InstalledPluginsFile.self, from: data),
              let plugins = file.plugins else {
            logger.warning("Failed to parse installed_plugins.json", metadata: [
                "path": "\(path.path)",
            ])
            return [:]
        }

        var projectEnabledCache: [String: [String: Bool]] = [:]
        var localEnabledCache: [String: [String: Bool]] = [:]
        let isoFormatter = ISO8601DateFormatter()

        func enabledMap(for scope: Skill.PluginScope, projectPath: String?) -> [String: Bool] {
            switch scope {
            case .user:
                return globalEnabled
            case .project:
                guard let projectPath else { return [:] }
                if let cached = projectEnabledCache[projectPath] { return cached }
                let settingsURL = URL(fileURLWithPath: projectPath)
                    .appendingPathComponent(".claude")
                    .appendingPathComponent("settings.json")
                let enabled = readEnabledPlugins(from: settingsURL)
                projectEnabledCache[projectPath] = enabled
                return enabled
            case .local:
                guard let projectPath else { return [:] }
                if let cached = localEnabledCache[projectPath] { return cached }
                let settingsURL = URL(fileURLWithPath: projectPath)
                    .appendingPathComponent(".claude")
                    .appendingPathComponent("settings.local.json")
                let enabled = readEnabledPlugins(from: settingsURL)
                localEnabledCache[projectPath] = enabled
                return enabled
            }
        }

        var result: [String: PluginInstallInfo] = [:]

        for (pluginKey, entries) in plugins {
            let parts = pluginKey.split(separator: "@", maxSplits: 1).map(String.init)
            let pluginName = parts.first ?? pluginKey
            let marketplaceName = parts.count > 1 ? parts[1] : ""

            for entry in entries {
                let installURL = URL(fileURLWithPath: entry.installPath).standardizedFileURL
                let enabled = enabledMap(for: entry.scope, projectPath: entry.projectPath)
                let isEnabled = enabled[pluginKey] ?? true
                let lastUpdated = entry.lastUpdated.flatMap { isoFormatter.date(from: $0) }
                let projectURL = entry.projectPath.map { URL(fileURLWithPath: $0) }

                let info = PluginInstallInfo(
                    pluginKey: pluginKey,
                    pluginName: pluginName,
                    marketplaceName: marketplaceName,
                    scope: entry.scope,
                    installPath: installURL.path,
                    projectPath: projectURL,
                    lastUpdated: lastUpdated,
                    isEnabled: isEnabled
                )
                result[installURL.path] = info
            }
        }

        return result
    }

    private static func readMarketplaceRepos(from path: URL?) -> [String: String] {
        guard let path, FileManager.default.fileExists(atPath: path.path) else {
            return [:]
        }

        struct MarketplaceInfo: Codable {
            let source: MarketplaceSource?
            struct MarketplaceSource: Codable {
                let source: String?
                let repo: String?
            }
        }

        do {
            let data = try Data(contentsOf: path)
            let marketplaces = try JSONDecoder().decode([String: MarketplaceInfo].self, from: data)

            var repos: [String: String] = [:]
            for (name, info) in marketplaces {
                if let repo = info.source?.repo {
                    repos[name] = repo
                }
            }
            return repos
        } catch {
            logger.warning("Failed to parse known_marketplaces.json", metadata: [
                "path": "\(path.path)",
                "error": "\(error.localizedDescription)",
            ])
            return [:]
        }
    }
}
