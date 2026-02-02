import Foundation

/// Source type for a skill
public enum SkillSource: String, Sendable, CaseIterable, Codable {
    /// Global skills from ~/<agent>/skills/
    case global

    /// Skills from installed plugins ~/<agent>/plugins/.../skills/
    case plugin

    /// Project-specific skills from <project>/<agent>/skills/
    case project

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .plugin:
            return "Plugin"
        case .project:
            return "Project"
        }
    }

    /// SF Symbol name for UI
    public var sfSymbolName: String {
        switch self {
        case .global:
            return "globe"
        case .plugin:
            return "puzzlepiece.extension"
        case .project:
            return "folder"
        }
    }

    /// Sort order for display (project first, then plugin, then global)
    public var sortOrder: Int {
        switch self {
        case .project:
            return 0
        case .plugin:
            return 1
        case .global:
            return 2
        }
    }
}
