import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Status of agent support in SkillsBar
public enum AgentStatus: String, Sendable, CaseIterable {
    case active       // Fully supported
    case beta         // Experimental support
    case comingSoon   // Planned but not yet implemented
}

/// Represents an AI coding agent supported by SkillsBar
public struct Agent: Identifiable, Hashable, Sendable {
    /// Unique identifier for the agent (e.g., "claude", "cursor")
    public let id: String

    /// Display name for UI (e.g., "Claude Code", "Cursor")
    public let displayName: String

    /// Short tagline describing the agent
    public let tagline: String

    /// Name of the config directory (e.g., ".claude", ".cursor")
    public let configDirName: String

    /// Whether this agent supports plugins with skills
    public let supportsPlugins: Bool

    /// Name of the skill file (typically "SKILL.md")
    public let skillFileName: String

    /// Current support status
    public let status: AgentStatus

    /// Name of the SVG icon in Resources (e.g., "claude" for ProviderIcon-claude.svg)
    public let iconName: String

    /// Brand accent color (hex string)
    public let accentColorHex: String

    /// Official website URL
    public let websiteURL: String?

    public init(
        id: String,
        displayName: String,
        tagline: String = "",
        configDirName: String,
        supportsPlugins: Bool,
        skillFileName: String = "SKILL.md",
        status: AgentStatus = .comingSoon,
        iconName: String? = nil,
        accentColorHex: String = "#6366F1",
        websiteURL: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.tagline = tagline
        self.configDirName = configDirName
        self.supportsPlugins = supportsPlugins
        self.skillFileName = skillFileName
        self.status = status
        self.iconName = iconName ?? id
        self.accentColorHex = accentColorHex
        self.websiteURL = websiteURL
    }

    #if canImport(SwiftUI)
    /// Accent color for SwiftUI
    public var accentColor: Color {
        Color(hex: accentColorHex) ?? .accentColor
    }
    #endif

    // MARK: - Path Accessors

    /// Path to global skills: ~/<configDirName>/skills/
    public var globalSkillsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(configDirName)
            .appendingPathComponent("skills")
    }

    /// Path to plugins directory (if supported): ~/<configDirName>/plugins/
    public var pluginsPath: URL? {
        guard supportsPlugins else { return nil }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(configDirName)
            .appendingPathComponent("plugins")
    }

    /// Path to plugins cache directory: ~/<configDirName>/plugins/cache/
    /// This is where Claude Code stores installed plugin files
    public var pluginsCachePath: URL? {
        pluginsPath?.appendingPathComponent("cache")
    }

    /// Path to project skills: <projectRoot>/<configDirName>/skills/
    public func projectSkillsPath(projectRoot: URL) -> URL {
        projectRoot
            .appendingPathComponent(configDirName)
            .appendingPathComponent("skills")
    }

    /// Path to settings.json: ~/<configDirName>/settings.json
    /// Contains enabledPlugins configuration
    public var settingsPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(configDirName)
            .appendingPathComponent("settings.json")
    }

    /// Path to known_marketplaces.json: ~/<configDirName>/plugins/known_marketplaces.json
    /// Contains marketplace source info (GitHub repos)
    public var knownMarketplacesPath: URL? {
        pluginsPath?.appendingPathComponent("known_marketplaces.json")
    }
}

// MARK: - Color Extension

#if canImport(SwiftUI)
import SwiftUI

public extension Color {
    /// Initialize a Color from a hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        switch length {
        case 6:
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8:
            self.init(
                red: Double((rgb & 0xFF00_0000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF_0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000_FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x0000_00FF) / 255.0
            )
        default:
            return nil
        }
    }
}
#endif
