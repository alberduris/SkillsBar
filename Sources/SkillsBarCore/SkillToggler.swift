import Foundation
import Logging

/// Manages enabling/disabling skills by manipulating symlinks or moving directories.
///
/// Two strategies based on `Skill.ToggleCapability`:
/// - `.symlink`: Removes/recreates the symlink (canonical copy in .agents/ is untouched)
/// - `.move`: Moves the skill directory to/from a `.disabled/` sibling directory
public struct SkillToggler: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.SkillToggler")

    /// Name of the directory where move-disabled skills are stored
    static let disabledDirName = ".disabled"

    // MARK: - Public API

    /// Toggle a skill's enabled state. Returns the new enabled state.
    @discardableResult
    public static func toggle(_ skill: Skill) throws -> Bool {
        if skill.isEnabled {
            try disable(skill)
            return false
        } else {
            try enable(skill)
            return true
        }
    }

    /// Disable a skill (remove symlink or move to .disabled/)
    public static func disable(_ skill: Skill) throws {
        guard skill.isToggleable else {
            throw ToggleError.notToggleable(skill.name)
        }

        guard skill.isEnabled else {
            logger.debug("Skill already disabled", metadata: ["skill": "\(skill.name)"])
            return
        }

        switch skill.toggleCapability {
        case .symlink:
            try disableSymlink(skill)
        case .move:
            try disableMove(skill)
        case .none:
            break
        }
    }

    /// Enable a skill (recreate symlink or move from .disabled/)
    public static func enable(_ skill: Skill) throws {
        guard skill.isToggleable else {
            throw ToggleError.notToggleable(skill.name)
        }

        guard !skill.isEnabled else {
            logger.debug("Skill already enabled", metadata: ["skill": "\(skill.name)"])
            return
        }

        switch skill.toggleCapability {
        case .symlink:
            try enableSymlink(skill)
        case .move:
            try enableMove(skill)
        case .none:
            break
        }
    }

    // MARK: - Symlink Strategy

    private static func disableSymlink(_ skill: Skill) throws {
        let symlinkPath = skill.path.path

        // Verify it's actually a symlink before removing
        guard isSymlink(atPath: symlinkPath) else {
            throw ToggleError.expectedSymlink(skill.name, symlinkPath)
        }

        try FileManager.default.removeItem(atPath: symlinkPath)

        logger.info("Disabled skill (removed symlink)", metadata: [
            "skill": "\(skill.name)",
            "symlink": "\(symlinkPath)",
        ])
    }

    private static func enableSymlink(_ skill: Skill) throws {
        guard let canonicalPath = skill.canonicalPath else {
            throw ToggleError.noCanonicalPath(skill.name)
        }

        // Verify canonical copy still exists
        guard FileManager.default.fileExists(atPath: canonicalPath.path) else {
            throw ToggleError.canonicalMissing(skill.name, canonicalPath.path)
        }

        // skill.path is where the symlink should be recreated
        let symlinkPath = skill.path

        // Ensure parent directory exists
        let parentDir = symlinkPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir, withIntermediateDirectories: true)

        try FileManager.default.createSymbolicLink(
            at: symlinkPath, withDestinationURL: canonicalPath)

        logger.info("Enabled skill (recreated symlink)", metadata: [
            "skill": "\(skill.name)",
            "symlink": "\(symlinkPath.path)",
            "target": "\(canonicalPath.path)",
        ])
    }

    // MARK: - Move Strategy

    private static func disableMove(_ skill: Skill) throws {
        let skillDir = skill.path
        let parentDir = skillDir.deletingLastPathComponent()
        let disabledDir = parentDir.appendingPathComponent(disabledDirName)
        let destination = disabledDir.appendingPathComponent(skillDir.lastPathComponent)

        // Create .disabled/ if needed
        try FileManager.default.createDirectory(
            at: disabledDir, withIntermediateDirectories: true)

        // Move the skill directory
        try FileManager.default.moveItem(at: skillDir, to: destination)

        logger.info("Disabled skill (moved to .disabled/)", metadata: [
            "skill": "\(skill.name)",
            "from": "\(skillDir.path)",
            "to": "\(destination.path)",
        ])
    }

    private static func enableMove(_ skill: Skill) throws {
        guard let canonicalPath = skill.canonicalPath else {
            throw ToggleError.noCanonicalPath(skill.name)
        }

        // canonicalPath points to the .disabled/<name> location
        guard FileManager.default.fileExists(atPath: canonicalPath.path) else {
            throw ToggleError.canonicalMissing(skill.name, canonicalPath.path)
        }

        // skill.path is where it should be restored to
        let destination = skill.path

        // Ensure parent directory exists
        let parentDir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir, withIntermediateDirectories: true)

        try FileManager.default.moveItem(at: canonicalPath, to: destination)

        // Clean up .disabled/ if empty
        let disabledDir = canonicalPath.deletingLastPathComponent()
        removeIfEmpty(disabledDir)

        logger.info("Enabled skill (moved from .disabled/)", metadata: [
            "skill": "\(skill.name)",
            "from": "\(canonicalPath.path)",
            "to": "\(destination.path)",
        ])
    }

    // MARK: - Detection Helpers

    /// Check if a path is a symlink
    public static func isSymlink(atPath path: String) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return attrs?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    /// Resolve symlink target for a skill directory
    public static func symlinkTarget(atPath path: String) -> String? {
        guard isSymlink(atPath: path) else { return nil }
        return try? FileManager.default.destinationOfSymbolicLink(atPath: path)
    }

    /// Check if a symlink points into a .agents/skills/ directory
    public static func isAgentsSymlink(atPath path: String) -> Bool {
        guard let target = symlinkTarget(atPath: path) else { return false }
        return target.contains(".agents/skills/") || target.contains(".agents/skills\\")
    }

    /// Determine the toggle capability for a skill at a given path
    public static func detectCapability(
        atPath path: URL,
        source: SkillSource
    ) -> (capability: Skill.ToggleCapability, canonicalPath: URL?) {
        guard source == .global || source == .project else {
            return (.none, nil)
        }

        let pathStr = path.path

        if isSymlink(atPath: pathStr) {
            // resolvingSymlinksInPath() follows the symlink to its absolute target
            let resolved = path.resolvingSymlinksInPath()
            if FileManager.default.fileExists(atPath: resolved.path) {
                return (.symlink, resolved)
            }
            return (.symlink, nil)
        }

        // Not a symlink — not toggleable from SkillsBar (for now)
        return (.none, nil)
    }

    // MARK: - Private Helpers

    private static func removeIfEmpty(_ dir: URL) {
        let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        if contents?.isEmpty == true {
            try? FileManager.default.removeItem(at: dir)
        }
    }
}

// MARK: - Errors

extension SkillToggler {
    public enum ToggleError: LocalizedError {
        case notToggleable(String)
        case expectedSymlink(String, String)
        case noCanonicalPath(String)
        case canonicalMissing(String, String)

        public var errorDescription: String? {
            switch self {
            case .notToggleable(let name):
                return "Skill '\(name)' cannot be toggled from SkillsBar"
            case .expectedSymlink(let name, let path):
                return "Expected '\(name)' at '\(path)' to be a symlink"
            case .noCanonicalPath(let name):
                return "No canonical path available for skill '\(name)'"
            case .canonicalMissing(let name, let path):
                return "Canonical copy for '\(name)' not found at '\(path)'"
            }
        }
    }
}
