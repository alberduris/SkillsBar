import Foundation
import Logging

/// Discovers project-specific skills from <project>/<agent>/skills/
public struct ProjectSkillsSource: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.ProjectSkillsSource")

    /// Discover project skills for an agent at a specific project root
    public static func discover(for agent: Agent, at projectRoot: URL) async -> [Skill] {
        let skillsPath = agent.projectSkillsPath(projectRoot: projectRoot)

        guard FileManager.default.fileExists(atPath: skillsPath.path) else {
            logger.debug("No project skills directory found", metadata: [
                "agent": "\(agent.id)",
                "project": "\(projectRoot.path)",
                "path": "\(skillsPath.path)",
            ])
            return []
        }

        return await GlobalSkillsSource.discoverSkills(
            in: skillsPath,
            agent: agent,
            source: .project,
            pluginName: nil,
            projectRoot: projectRoot
        )
    }

    /// Discover project skills by searching up the directory tree from a starting path
    /// Useful for finding project roots in monorepos
    public static func discoverWithAncestorSearch(
        for agent: Agent,
        startingFrom startPath: URL,
        maxDepth: Int = 5
    ) async -> [Skill] {
        var currentPath = startPath
        var allSkills: [Skill] = []
        var depth = 0

        while depth < maxDepth {
            let skills = await discover(for: agent, at: currentPath)
            allSkills.append(contentsOf: skills)

            // Move to parent directory
            let parentPath = currentPath.deletingLastPathComponent()
            if parentPath.path == currentPath.path {
                // Reached root
                break
            }
            currentPath = parentPath
            depth += 1
        }

        // Remove duplicates (prefer closer paths)
        let uniqueSkills = Dictionary(grouping: allSkills, by: \.id)
            .compactMapValues(\.first)
            .values

        return Array(uniqueSkills)
    }
}
