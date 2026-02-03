import Foundation
import Logging

/// Discovers global skills from ~/<agent>/skills/
public struct GlobalSkillsSource: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.GlobalSkillsSource")

    /// Discover global skills for an agent
    public static func discover(for agent: Agent) async -> [Skill] {
        let skillsPath = agent.globalSkillsPath

        guard FileManager.default.fileExists(atPath: skillsPath.path) else {
            logger.debug("No global skills directory found", metadata: [
                "agent": "\(agent.id)",
                "path": "\(skillsPath.path)",
            ])
            return []
        }

        return await discoverSkills(
            in: skillsPath,
            agent: agent,
            source: .global,
            pluginName: nil
        )
    }

    /// Discover skills in a directory
    /// - Parameters:
    ///   - directory: Directory containing skill folders
    ///   - agent: Agent the skills belong to
    ///   - source: Source type (global, plugin, project)
    ///   - pluginName: Plugin name if source is .plugin
    ///   - marketplaceName: Marketplace name if source is .plugin
    ///   - marketplaceRepo: Marketplace GitHub repo if source is .plugin (e.g., "user/repo")
    ///   - projectRoot: Project root if source is .project
    ///   - pluginScope: Plugin install scope if source is .plugin
    ///   - isEnabled: Whether the source (plugin) is enabled (default: true)
    static func discoverSkills(
        in directory: URL,
        agent: Agent,
        source: SkillSource,
        pluginName: String?,
        marketplaceName: String? = nil,
        marketplaceRepo: String? = nil,
        projectRoot: URL? = nil,
        pluginScope: Skill.PluginScope? = nil,
        isEnabled: Bool = true
    ) async -> [Skill] {
        var skills: [Skill] = []

        let fileManager = FileManager.default

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                // Check if it's a directory
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                // Check for SKILL.md file
                let skillFile = item.appendingPathComponent(agent.skillFileName)
                guard fileManager.fileExists(atPath: skillFile.path) else {
                    continue
                }

                // Parse the skill file
                do {
                    let parseResult = try SKILLMDParser.parse(at: skillFile)

                    let skill = Skill(
                        id: makeSkillID(
                            agent: agent,
                            source: source,
                            path: item,
                            pluginName: pluginName,
                            marketplaceName: marketplaceName,
                            projectRoot: projectRoot,
                            pluginScope: pluginScope),
                        name: parseResult.name,
                        description: parseResult.description,
                        agent: agent,
                        source: source,
                        path: item,
                        pluginName: pluginName,
                        marketplaceName: marketplaceName,
                        marketplaceRepo: marketplaceRepo,
                        projectRoot: projectRoot,
                        pluginScope: pluginScope,
                        metadata: parseResult.metadata,
                        isEnabled: isEnabled
                    )

                    skills.append(skill)
                    logger.debug("Discovered skill", metadata: [
                        "name": "\(skill.name)",
                        "source": "\(source.rawValue)",
                        "agent": "\(agent.id)",
                        "isEnabled": "\(isEnabled)",
                    ])
                } catch {
                    logger.warning("Failed to parse skill file", metadata: [
                        "path": "\(skillFile.path)",
                        "error": "\(error.localizedDescription)",
                    ])
                }
            }
        } catch {
            logger.warning("Failed to read skills directory", metadata: [
                "path": "\(directory.path)",
                "error": "\(error.localizedDescription)",
            ])
        }

        return skills
    }

    /// Create a unique skill ID from its components
    static func makeSkillID(
        agent: Agent,
        source: SkillSource,
        path: URL,
        pluginName: String?,
        marketplaceName: String? = nil,
        projectRoot: URL? = nil,
        pluginScope: Skill.PluginScope? = nil
    ) -> String {
        var components = [agent.id, source.rawValue]
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
}
