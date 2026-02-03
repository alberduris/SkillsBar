import Foundation

/// Discovers MCP servers provided by installed Claude Code plugins
public struct PluginMCPSource: Sendable {
    private static let logger = SkillsBarLog.logger(LogCategories.mcpDiscovery)

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

    /// Discover MCP servers from installed plugins
    public static func discover(
        for agent: Agent = AgentRegistry.defaultAgent,
        includeGlobal: Bool,
        includeProject: Bool,
        projectPaths: [URL]
    ) -> [MCPServer] {
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
        var servers: [MCPServer] = []

        for info in installInfoByPath.values {
            let source: MCPSource
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
            let mcpURL = installURL.appendingPathComponent(".mcp.json")
            guard FileManager.default.fileExists(atPath: mcpURL.path) else {
                continue
            }

            guard let rawServers = parsePluginMcpFile(at: mcpURL) else {
                logger.debug("Failed to parse plugin MCP file", metadata: [
                    "plugin": "\(info.pluginName)",
                    "path": "\(mcpURL.path)",
                ])
                continue
            }

            let projectName = info.projectPath?.lastPathComponent
            let marketplaceRepo = marketplaceRepos[info.marketplaceName]

            for (name, entry) in rawServers {
                if let server = makePluginServer(
                    name: name,
                    rawEntry: entry,
                    source: source,
                    projectName: projectName,
                    pluginInfo: info,
                    marketplaceRepo: marketplaceRepo
                ) {
                    servers.append(server)
                }
            }
        }

        return servers.sorted()
    }

    // MARK: - Parsing Helpers

    private static func parsePluginMcpFile(
        at url: URL
    ) -> [String: MCPConfigParser.RawServerEntry]? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        struct MCPFile: Codable {
            let mcpServers: [String: MCPConfigParser.RawServerEntry]?
        }

        let decoder = JSONDecoder()
        if let file = try? decoder.decode(MCPFile.self, from: data),
           let servers = file.mcpServers, !servers.isEmpty {
            return servers
        }

        return try? decoder.decode([String: MCPConfigParser.RawServerEntry].self, from: data)
    }

    private static func makePluginServer(
        name: String,
        rawEntry: MCPConfigParser.RawServerEntry,
        source: MCPSource,
        projectName: String?,
        pluginInfo: PluginInstallInfo,
        marketplaceRepo: String?
    ) -> MCPServer? {
        let transport: MCPTransport
        if let typeStr = rawEntry.type, let t = MCPTransport(rawValue: typeStr) {
            transport = t
        } else if rawEntry.command != nil {
            transport = .stdio
        } else if rawEntry.url != nil {
            transport = .http
        } else {
            logger.warning("Cannot determine transport for plugin MCP", metadata: [
                "plugin": "\(pluginInfo.pluginName)",
                "server": "\(name)",
            ])
            return nil
        }

        var idParts = ["mcp", source.rawValue]
        if let projectName {
            idParts.append(projectName)
        }
        idParts.append("plugin")
        idParts.append(pluginInfo.pluginName)
        idParts.append(name)
        let id = idParts.joined(separator: ":")

        let envKeys = rawEntry.env.map { Array($0.keys).sorted() } ?? []
        let headerKeys = rawEntry.headers.map { Array($0.keys).sorted() } ?? []

        return MCPServer(
            id: id,
            name: name,
            transport: transport,
            url: rawEntry.url,
            command: rawEntry.command,
            args: rawEntry.args ?? [],
            envKeys: envKeys,
            headerKeys: headerKeys,
            source: source,
            projectName: projectName,
            pluginName: pluginInfo.pluginName,
            marketplaceName: pluginInfo.marketplaceName,
            marketplaceRepo: marketplaceRepo,
            pluginScope: pluginInfo.scope,
            isEnabled: pluginInfo.isEnabled
        )
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
