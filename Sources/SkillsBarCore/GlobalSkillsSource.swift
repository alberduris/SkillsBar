import Foundation
import Logging

/// Discovers global skills from ~/<agent>/skills/
public struct GlobalSkillsSource: Sendable {
    private static let logger = Logger(label: "SkillsBarCore.GlobalSkillsSource")

    /// Discover global skills for an agent (enabled + disabled)
    public static func discover(for agent: Agent) async -> [Skill] {
        let skillsPath = agent.globalSkillsPath

        var allSkills: [Skill] = []

        // Discover enabled skills from the agent's skills directory
        if FileManager.default.fileExists(atPath: skillsPath.path) {
            let enabled = await discoverSkills(
                in: skillsPath,
                agent: agent,
                source: .global,
                pluginName: nil,
                detectToggle: true
            )
            allSkills.append(contentsOf: enabled)
        }

        // Discover disabled skills from .agents/skills/ (symlink-based)
        let disabled = await discoverDisabledFromAgentsDir(
            agentSkillsPath: skillsPath,
            agent: agent,
            source: .global,
            enabledNames: Set(allSkills.map(\.name))
        )
        allSkills.append(contentsOf: disabled)

        // Discover disabled skills from .disabled/ directory (move-based)
        let disabledDir = skillsPath.appendingPathComponent(SkillToggler.disabledDirName)
        if FileManager.default.fileExists(atPath: disabledDir.path) {
            let moveDisabled = await discoverSkills(
                in: disabledDir,
                agent: agent,
                source: .global,
                pluginName: nil,
                isEnabled: false,
                overrideToggleCapability: .move,
                restoreParentPath: skillsPath
            )
            allSkills.append(contentsOf: moveDisabled)
        }

        return allSkills
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
    ///   - detectToggle: Whether to detect toggle capability (default: false for plugins)
    ///   - overrideToggleCapability: Force a specific toggle capability (used for .disabled/ discovery)
    ///   - restoreParentPath: The parent path where a move-disabled skill should be restored to
    static func discoverSkills(
        in directory: URL,
        agent: Agent,
        source: SkillSource,
        pluginName: String?,
        marketplaceName: String? = nil,
        marketplaceRepo: String? = nil,
        projectRoot: URL? = nil,
        pluginScope: Skill.PluginScope? = nil,
        isEnabled: Bool = true,
        detectToggle: Bool = false,
        overrideToggleCapability: Skill.ToggleCapability? = nil,
        restoreParentPath: URL? = nil
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
                // Check if it's a directory (resolve symlinks for the check)
                let resolvedPath = item.resolvingSymlinksInPath()
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: resolvedPath.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                // Check for SKILL.md file (follow symlinks)
                let skillFile = resolvedPath.appendingPathComponent(agent.skillFileName)
                guard fileManager.fileExists(atPath: skillFile.path) else {
                    continue
                }

                // Detect toggle capability
                let toggleCapability: Skill.ToggleCapability
                let canonicalPath: URL?

                if let override = overrideToggleCapability {
                    toggleCapability = override
                    // For move-disabled skills, canonicalPath = current location in .disabled/
                    // skill.path = where it should be restored to
                    canonicalPath = item
                } else if detectToggle {
                    let detected = SkillToggler.detectCapability(
                        atPath: item, source: source)
                    toggleCapability = detected.capability
                    canonicalPath = detected.canonicalPath
                } else {
                    toggleCapability = .none
                    canonicalPath = nil
                }

                // For move-disabled skills, the "path" should be the restore destination
                let skillPath: URL
                if overrideToggleCapability == .move, let restoreParent = restoreParentPath {
                    skillPath = restoreParent.appendingPathComponent(item.lastPathComponent)
                } else {
                    skillPath = item
                }

                // Parse the skill file
                do {
                    let parseResult = try SKILLMDParser.parse(at: skillFile)

                    let skill = Skill(
                        id: makeSkillID(
                            agent: agent,
                            source: source,
                            path: skillPath,
                            pluginName: pluginName,
                            marketplaceName: marketplaceName,
                            projectRoot: projectRoot,
                            pluginScope: pluginScope),
                        name: parseResult.name,
                        description: parseResult.description,
                        agent: agent,
                        source: source,
                        path: skillPath,
                        pluginName: pluginName,
                        marketplaceName: marketplaceName,
                        marketplaceRepo: marketplaceRepo,
                        projectRoot: projectRoot,
                        pluginScope: pluginScope,
                        metadata: parseResult.metadata,
                        isEnabled: isEnabled,
                        toggleCapability: toggleCapability,
                        canonicalPath: canonicalPath
                    )

                    skills.append(skill)
                    logger.debug("Discovered skill", metadata: [
                        "name": "\(skill.name)",
                        "source": "\(source.rawValue)",
                        "agent": "\(agent.id)",
                        "isEnabled": "\(isEnabled)",
                        "toggle": "\(toggleCapability.rawValue)",
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

    /// Discover disabled symlink-based skills by scanning .agents/skills/
    /// Returns skills that exist in .agents/ but have no symlink in the agent's skills dir
    static func discoverDisabledFromAgentsDir(
        agentSkillsPath: URL,
        agent: Agent,
        source: SkillSource,
        projectRoot: URL? = nil,
        enabledNames: Set<String>
    ) async -> [Skill] {
        // Determine the .agents/skills/ path
        let agentsSkillsPath: URL
        if let projectRoot {
            agentsSkillsPath = projectRoot
                .appendingPathComponent(".agents")
                .appendingPathComponent("skills")
        } else {
            agentsSkillsPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".agents")
                .appendingPathComponent("skills")
        }

        guard FileManager.default.fileExists(atPath: agentsSkillsPath.path) else {
            return []
        }

        let fileManager = FileManager.default
        var disabledSkills: [Skill] = []

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: agentsSkillsPath,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents {
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory),
                      isDirectory.boolValue else {
                    continue
                }

                let skillName = item.lastPathComponent

                // Skip if already discovered as enabled
                if enabledNames.contains(skillName) { continue }

                // Check for SKILL.md in the canonical location
                let skillFile = item.appendingPathComponent(agent.skillFileName)
                guard fileManager.fileExists(atPath: skillFile.path) else {
                    continue
                }

                // This skill exists in .agents/ but not in the agent's skills dir → disabled
                let expectedSymlinkPath = agentSkillsPath
                    .appendingPathComponent(skillName)

                do {
                    let parseResult = try SKILLMDParser.parse(at: skillFile)

                    let skill = Skill(
                        id: makeSkillID(
                            agent: agent,
                            source: source,
                            path: expectedSymlinkPath,
                            pluginName: nil,
                            projectRoot: projectRoot),
                        name: parseResult.name,
                        description: parseResult.description,
                        agent: agent,
                        source: source,
                        path: expectedSymlinkPath,
                        projectRoot: projectRoot,
                        metadata: parseResult.metadata,
                        isEnabled: false,
                        toggleCapability: .symlink,
                        canonicalPath: item
                    )

                    disabledSkills.append(skill)
                    logger.debug("Discovered disabled skill (no symlink)", metadata: [
                        "name": "\(skill.name)",
                        "canonical": "\(item.path)",
                        "expected": "\(expectedSymlinkPath.path)",
                    ])
                } catch {
                    logger.warning("Failed to parse disabled skill", metadata: [
                        "path": "\(skillFile.path)",
                        "error": "\(error.localizedDescription)",
                    ])
                }
            }
        } catch {
            logger.debug("Failed to read .agents/skills/", metadata: [
                "path": "\(agentsSkillsPath.path)",
                "error": "\(error.localizedDescription)",
            ])
        }

        return disabledSkills
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
