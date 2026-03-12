import Foundation
import SkillsBarCore

enum InventorySectionsBuilder {
    static func buildContent(
        for tab: InventoryTab,
        snapshot: InventorySnapshot,
        filterText: String
    ) -> InventoryTabContent {
        switch tab {
        case .skills:
            return buildSkillsContent(skills: snapshot.skills, filterText: filterText)
        case .mcps:
            return buildMCPContent(servers: snapshot.mcpServers, filterText: filterText)
        case .agents:
            return buildAgentsContent(agents: snapshot.agents, filterText: filterText)
        }
    }

    private static func buildSkillsContent(skills: [Skill], filterText: String) -> InventoryTabContent {
        let filterQuery = normalize(filterText)
        let isFiltering = !filterQuery.isEmpty
        var sections: [InventorySection] = []

        let globalSkills = skills.filter { skill in
            switch skill.source {
            case .global:
                return true
            case .plugin:
                let scope = skill.pluginScope ?? .user
                return scope == .user || skill.projectRoot == nil
            case .project:
                return false
            }
        }

        if !globalSkills.isEmpty {
            sections.append(makeEnabledAwareSection(
                id: "skills:global",
                title: "All Projects",
                icon: "globe",
                items: globalSkills.sorted().map(InventoryItem.from(skill:))
            ))
        }

        let projectScopedSkills = skills.filter { skill in
            switch skill.source {
            case .project:
                return true
            case .plugin:
                let scope = skill.pluginScope ?? .user
                return (scope == .local || scope == .project) && skill.projectRoot != nil
            case .global:
                return false
            }
        }

        let groupedByProject = Dictionary(grouping: projectScopedSkills) { skill in
            projectDisplayName(for: skill.projectRoot)
        }

        let visibleProjectNames = groupedByProject.keys.sorted().filter { projectName in
            !isFiltering || normalize(projectName).contains(filterQuery)
        }

        for projectName in visibleProjectNames {
            guard let projectSkills = groupedByProject[projectName] else { continue }
            sections.append(makeEnabledAwareSection(
                id: "skills:\(projectName)",
                title: projectName,
                icon: "folder",
                items: projectSkills.sorted().map(InventoryItem.from(skill:))
            ))
        }

        return InventoryTabContent(
            sections: sections,
            showsNoMatchesState: isFiltering && visibleProjectNames.isEmpty
        )
    }

    private static func buildMCPContent(servers: [MCPServer], filterText: String) -> InventoryTabContent {
        let filterQuery = normalize(filterText)
        let isFiltering = !filterQuery.isEmpty
        var sections: [InventorySection] = []
        var hasMatchingProject = false

        for source in MCPSource.allCases {
            let sourceServers = servers.filter { $0.source == source }
            guard !sourceServers.isEmpty else { continue }

            if source == .project {
                let groupedByProject = Dictionary(grouping: sourceServers) { $0.projectName ?? "Unknown" }
                let visibleProjectNames = groupedByProject.keys.sorted().filter { projectName in
                    !isFiltering || normalize(projectName).contains(filterQuery)
                }

                hasMatchingProject = !visibleProjectNames.isEmpty

                for projectName in visibleProjectNames {
                    guard let projectServers = groupedByProject[projectName] else { continue }
                    sections.append(makeMCPSection(
                        id: "mcps:\(source.rawValue):\(projectName)",
                        title: projectName,
                        icon: "server.rack",
                        items: projectServers.sorted().map(InventoryItem.from(server:)),
                        trailingText: "(\(projectServers.count))",
                        note: nil
                    ))
                }
            } else {
                sections.append(makeMCPSection(
                    id: "mcps:\(source.rawValue)",
                    title: source == .global ? "All Projects" : source.displayName,
                    icon: source == .builtIn ? source.sfSymbolName : "server.rack",
                    items: sourceServers.sorted().map(InventoryItem.from(server:)),
                    trailingText: source == .builtIn ? "always available" : "(\(sourceServers.count))",
                    note: source == .builtIn
                        ? "Runtime MCPs managed by Claude Code. Status reflects default config, not live connections."
                        : nil
                ))
            }
        }

        return InventoryTabContent(
            sections: sections,
            showsNoMatchesState: isFiltering && !hasMatchingProject
        )
    }

    private static func buildAgentsContent(agents: [AgentProfile], filterText: String) -> InventoryTabContent {
        let filterQuery = normalize(filterText)
        let isFiltering = !filterQuery.isEmpty
        var sections: [InventorySection] = []

        let globalAgents = agents.filter { agent in
            switch agent.source {
            case .global:
                return true
            case .plugin:
                let scope = agent.pluginScope ?? .user
                return scope == .user || agent.projectRoot == nil
            case .project:
                return false
            }
        }

        if !globalAgents.isEmpty {
            sections.append(makeEnabledAwareSection(
                id: "agents:global",
                title: "All Projects",
                icon: "globe",
                items: globalAgents.sorted().map(InventoryItem.from(agent:))
            ))
        }

        let projectScopedAgents = agents.filter { agent in
            switch agent.source {
            case .project:
                return true
            case .plugin:
                let scope = agent.pluginScope ?? .user
                return (scope == .local || scope == .project) && agent.projectRoot != nil
            case .global:
                return false
            }
        }

        let groupedByProject = Dictionary(grouping: projectScopedAgents) { agent in
            projectDisplayName(for: agent.projectRoot)
        }

        let visibleProjectNames = groupedByProject.keys.sorted().filter { projectName in
            !isFiltering || normalize(projectName).contains(filterQuery)
        }

        for projectName in visibleProjectNames {
            guard let projectAgents = groupedByProject[projectName] else { continue }
            sections.append(makeEnabledAwareSection(
                id: "agents:\(projectName)",
                title: projectName,
                icon: "folder",
                items: projectAgents.sorted().map(InventoryItem.from(agent:))
            ))
        }

        return InventoryTabContent(
            sections: sections,
            showsNoMatchesState: isFiltering && visibleProjectNames.isEmpty
        )
    }

    private static func makeEnabledAwareSection(
        id: String,
        title: String,
        icon: String,
        items: [InventoryItem]
    ) -> InventorySection {
        let enabledCount = items.filter(\.isEnabled).count
        let trailingText = enabledCount < items.count ? "(\(enabledCount)/\(items.count))" : "(\(items.count))"

        return InventorySection(
            id: id,
            title: title,
            icon: icon,
            items: items,
            trailingText: trailingText,
            note: nil
        )
    }

    private static func makeMCPSection(
        id: String,
        title: String,
        icon: String,
        items: [InventoryItem],
        trailingText: String,
        note: String?
    ) -> InventorySection {
        InventorySection(
            id: id,
            title: title,
            icon: icon,
            items: items,
            trailingText: trailingText,
            note: note
        )
    }

    private static func projectDisplayName(for projectRoot: URL?) -> String {
        guard let root = projectRoot else { return "Unknown" }
        let project = root.lastPathComponent
        let parent = root.deletingLastPathComponent().lastPathComponent
        if !parent.isEmpty && parent != "/" {
            return "\(parent)/\(project)"
        }
        return project
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
