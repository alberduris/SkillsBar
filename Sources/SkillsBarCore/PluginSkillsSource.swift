import Foundation
import Logging

/// Discovers skills from installed Claude Code plugins
/// Reads ~/.claude/settings.json for enabledPlugins and scans ~/.claude/plugins/cache/
///
/// Cache structure:
/// ```
/// ~/.claude/plugins/cache/
/// ├── <marketplace>/
/// │   └── <plugin>/
/// │       └── <version>/
/// │           ├── .claude-plugin/plugin.json
/// │           └── skills/<skill>/SKILL.md
/// ```
public struct PluginSkillsSource: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.PluginSkillsSource")

    /// Structure matching settings.json format
    struct ClaudeSettings: Codable {
        let enabledPlugins: [String: Bool]?
    }

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

    /// Structure matching known_marketplaces.json format
    struct KnownMarketplaces: Codable {
        // This is a dictionary keyed by marketplace name
    }

    struct MarketplaceInfo: Codable {
        let source: MarketplaceSource?

        struct MarketplaceSource: Codable {
            let source: String?  // "github"
            let repo: String?    // "user/repo"
        }
    }

    /// Discover ALL plugin skills for an agent (enabled and disabled)
    /// Skills from disabled plugins will have isEnabled = false
    public static func discover(for agent: Agent) async -> [Skill] {
        guard agent.supportsPlugins else {
            logger.debug("Agent does not support plugins", metadata: [
                "agent": "\(agent.id)",
            ])
            return []
        }

        guard let pluginsCachePath = agent.pluginsCachePath else {
            logger.debug("No plugins cache path for agent", metadata: [
                "agent": "\(agent.id)",
            ])
            return []
        }

        guard FileManager.default.fileExists(atPath: pluginsCachePath.path) else {
            logger.debug("Plugins cache directory does not exist", metadata: [
                "path": "\(pluginsCachePath.path)",
            ])
            return []
        }

        // Read enabled plugins from settings.json (user scope)
        let enabledPlugins = readEnabledPlugins(from: agent.settingsPath)

        // Read installed plugins (includes local/project scope info)
        let installedPluginsPath = agent.pluginsPath?.appendingPathComponent("installed_plugins.json")
        let installInfoByPath = readInstalledPlugins(
            from: installedPluginsPath,
            globalEnabled: enabledPlugins)

        // Read marketplace repos from known_marketplaces.json
        let marketplaceRepos = readMarketplaceRepos(from: agent.knownMarketplacesPath)

        logger.debug("Loaded plugin settings", metadata: [
            "agent": "\(agent.id)",
            "totalPluginsInSettings": "\(enabledPlugins.count)",
            "enabledCount": "\(enabledPlugins.filter { $0.value }.count)",
            "knownMarketplaces": "\(marketplaceRepos.count)",
        ])

        // Scan ALL plugins in cache, marking each with enabled status
        return await scanAllPlugins(
            cachePath: pluginsCachePath,
            enabledPlugins: enabledPlugins,
            marketplaceRepos: marketplaceRepos,
            agent: agent,
            installInfoByPath: installInfoByPath
        )
    }

    /// Read enabledPlugins from a settings file
    private static func readEnabledPlugins(from settingsPath: URL?) -> [String: Bool] {
        guard let settingsPath,
              FileManager.default.fileExists(atPath: settingsPath.path) else {
            logger.debug("settings.json not found", metadata: [
                "path": "\(settingsPath?.path ?? "nil")",
            ])
            return [:]
        }

        do {
            let data = try Data(contentsOf: settingsPath)
            let settings = try JSONDecoder().decode(ClaudeSettings.self, from: data)
            return settings.enabledPlugins ?? [:]
        } catch {
            logger.warning("Failed to parse settings.json", metadata: [
                "path": "\(settingsPath.path)",
                "error": "\(error.localizedDescription)",
            ])
            return [:]
        }
    }

    /// Read installed_plugins.json and map install path -> install info
    private static func readInstalledPlugins(
        from path: URL?,
        globalEnabled: [String: Bool]
    ) -> [String: PluginInstallInfo] {
        guard let path,
              FileManager.default.fileExists(atPath: path.path) else {
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

    /// Read marketplace repos from known_marketplaces.json
    /// Returns a dictionary mapping marketplace name to GitHub repo (e.g., "user/repo")
    private static func readMarketplaceRepos(from path: URL?) -> [String: String] {
        guard let path = path, FileManager.default.fileExists(atPath: path.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: path)
            // Parse as dictionary of marketplace name -> MarketplaceInfo
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

    /// Scan ALL plugins in the cache directory
    /// Structure: cache/<marketplace>/<plugin>/<version>/skills/
    private static func scanAllPlugins(
        cachePath: URL,
        enabledPlugins: [String: Bool],
        marketplaceRepos: [String: String],
        agent: Agent,
        installInfoByPath: [String: PluginInstallInfo]
    ) async -> [Skill] {
        var skills: [Skill] = []

        // List all marketplace directories
        let marketplaces: [URL]
        do {
            marketplaces = try FileManager.default.contentsOfDirectory(
                at: cachePath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { isDirectory($0) }
        } catch {
            logger.warning("Failed to list cache directory", metadata: [
                "path": "\(cachePath.path)",
                "error": "\(error.localizedDescription)",
            ])
            return []
        }

        for marketplaceURL in marketplaces {
            let marketplaceName = marketplaceURL.lastPathComponent

            // List all plugin directories in this marketplace
            let plugins: [URL]
            do {
                plugins = try FileManager.default.contentsOfDirectory(
                    at: marketplaceURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ).filter { isDirectory($0) }
            } catch {
                logger.warning("Failed to list marketplace directory", metadata: [
                    "marketplace": "\(marketplaceName)",
                    "error": "\(error.localizedDescription)",
                ])
                continue
            }

            for pluginURL in plugins {
                let pluginName = pluginURL.lastPathComponent

                let pluginKey = "\(pluginName)@\(marketplaceName)"

                // Get the GitHub repo for this marketplace
                let marketplaceRepo = marketplaceRepos[marketplaceName]

                // Find the latest version
                guard let versionDir = findLatestVersion(in: pluginURL) else {
                    logger.debug("No version directory found for plugin", metadata: [
                        "plugin": "\(pluginName)",
                        "marketplace": "\(marketplaceName)",
                    ])
                    continue
                }

                // Verify this is a valid plugin (accept plugin.json or marketplace.json)
                let pluginManifestPath = versionDir
                    .appendingPathComponent(".claude-plugin")
                    .appendingPathComponent("plugin.json")
                let marketplaceManifestPath = versionDir
                    .appendingPathComponent(".claude-plugin")
                    .appendingPathComponent("marketplace.json")

                let hasPluginManifest = FileManager.default.fileExists(atPath: pluginManifestPath.path)
                let hasMarketplaceManifest = FileManager.default.fileExists(atPath: marketplaceManifestPath.path)

                guard hasPluginManifest || hasMarketplaceManifest else {
                    logger.debug("Plugin version missing manifest", metadata: [
                        "plugin": "\(pluginName)",
                        "version": "\(versionDir.lastPathComponent)",
                    ])
                    continue
                }

                // Look for skills directory
                let skillsPath = versionDir.appendingPathComponent("skills")

                guard FileManager.default.fileExists(atPath: skillsPath.path) else {
                    logger.debug("Plugin has no skills directory", metadata: [
                        "plugin": "\(pluginName)",
                        "version": "\(versionDir.lastPathComponent)",
                    ])
                    continue
                }

                // Resolve install info (scope/project/enablement)
                let installInfo = installInfoByPath[versionDir.standardizedFileURL.path]
                let resolvedEnabled = installInfo?.isEnabled ?? (enabledPlugins[pluginKey] ?? false)
                let resolvedProjectRoot = installInfo?.projectPath
                let resolvedScope = installInfo?.scope

                // Discover skills, passing enabled status and marketplace
                let pluginSkills = await GlobalSkillsSource.discoverSkills(
                    in: skillsPath,
                    agent: agent,
                    source: .plugin,
                    pluginName: pluginName,
                    marketplaceName: marketplaceName,
                    marketplaceRepo: marketplaceRepo,
                    projectRoot: resolvedProjectRoot,
                    pluginScope: resolvedScope,
                    isEnabled: resolvedEnabled
                )

                logger.debug("Discovered skills from plugin", metadata: [
                    "plugin": "\(pluginName)",
                    "marketplace": "\(marketplaceName)",
                    "repo": "\(marketplaceRepo ?? "unknown")",
                    "version": "\(versionDir.lastPathComponent)",
                    "skillCount": "\(pluginSkills.count)",
                    "isEnabled": "\(resolvedEnabled)",
                ])

                skills.append(contentsOf: pluginSkills)
            }
        }

        return skills
    }

    /// Check if a URL is a directory
    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    /// Find the latest version directory in a plugin directory
    /// Handles both semver (1.2.0) and commit hashes (e30768372b41)
    private static func findLatestVersion(in pluginPath: URL) -> URL? {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: pluginPath,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            logger.warning("Failed to list plugin directory", metadata: [
                "path": "\(pluginPath.path)",
                "error": "\(error.localizedDescription)",
            ])
            return nil
        }

        // Filter to directories only
        let directories = contents.filter { isDirectory($0) }

        guard !directories.isEmpty else {
            return nil
        }

        // If only one version, return it
        if directories.count == 1 {
            return directories[0]
        }

        // Try to sort by semver first
        let semverSorted = directories.sorted { a, b in
            let aVersion = a.lastPathComponent
            let bVersion = b.lastPathComponent
            return compareSemver(aVersion, bVersion) == .orderedDescending
        }

        // Check if the first one looks like semver
        if looksLikeSemver(semverSorted[0].lastPathComponent) {
            return semverSorted[0]
        }

        // Otherwise, sort by modification date (most recent first)
        let dateSorted = directories.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return aDate > bDate
        }

        return dateSorted.first
    }

    /// Check if a string looks like semver (e.g., "1.2.0", "1.0.0-beta")
    private static func looksLikeSemver(_ string: String) -> Bool {
        let pattern = #"^\d+\.\d+\.\d+.*$"#
        return string.range(of: pattern, options: .regularExpression) != nil
    }

    /// Compare two version strings (semver-style)
    private static func compareSemver(_ a: String, _ b: String) -> ComparisonResult {
        let aComponents = a.split(separator: ".").compactMap { Int($0.prefix(while: { $0.isNumber })) }
        let bComponents = b.split(separator: ".").compactMap { Int($0.prefix(while: { $0.isNumber })) }

        for i in 0..<max(aComponents.count, bComponents.count) {
            let aVal = i < aComponents.count ? aComponents[i] : 0
            let bVal = i < bComponents.count ? bComponents[i] : 0

            if aVal > bVal { return .orderedDescending }
            if aVal < bVal { return .orderedAscending }
        }

        return .orderedSame
    }
}
