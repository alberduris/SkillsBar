import Foundation
import SkillsBarCore

struct InventoryItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case skill
        case mcp
        case agent
    }

    enum Payload: Hashable {
        case skill(Skill)
        case mcp(MCPServer)
        case agent(AgentProfile)
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String?
    let description: String?
    let isEnabled: Bool
    let badges: [InventoryBadge]
    let sourceLabel: String?
    let scopeLabel: String?
    let primaryLocation: URL?
    let secondaryLocation: URL?
    let primaryURL: URL?
    let availableActions: [InventoryAction]
    let primaryAction: InventoryAction?
    let infoMessage: String?
    let isUserInvocable: Bool?
    let payload: Payload
}

extension InventoryItem {
    static func from(skill: Skill) -> InventoryItem {
        let sourceLabel: String?
        switch skill.source {
        case .plugin:
            sourceLabel = "Plugin"
        case .global, .project:
            sourceLabel = "Direct"
        }

        let scopeLabel = skill.source == .plugin ? (skill.pluginScope ?? .user).rawValue.capitalized : nil
        let scopeBadge = scopeLabel.map { InventoryBadge(text: $0, style: badgeStyle(for: skill.pluginScope)) }
        let sourceBadge = sourceLabel.map {
            InventoryBadge(text: $0, style: skill.source == .plugin ? .orange : .neutral)
        }

        var availableActions: [InventoryAction] = [.revealInFinder, .copyPath]
        if skill.isToggleable {
            availableActions.insert(.toggleEnabled, at: 0)
        } else {
            availableActions.append(.showInfo)
        }

        let finderTarget = skill.isEnabled ? skill.path : (skill.canonicalPath ?? skill.path)

        return InventoryItem(
            id: skill.id,
            kind: .skill,
            title: skill.name,
            subtitle: marketplaceDisplayName(
                repo: skill.marketplaceRepo,
                marketplaceName: skill.marketplaceName
            ),
            description: skill.description.isEmpty ? nil : skill.description,
            isEnabled: skill.isEnabled,
            badges: [sourceBadge, scopeBadge].compactMap { $0 },
            sourceLabel: sourceLabel,
            scopeLabel: scopeLabel,
            primaryLocation: finderTarget,
            secondaryLocation: skill.skillFilePath,
            primaryURL: nil,
            availableActions: availableActions,
            primaryAction: skill.isToggleable ? .toggleEnabled : nil,
            infoMessage: skill.isToggleable ? nil : nonToggleableReason(for: skill),
            isUserInvocable: skill.isUserInvocable,
            payload: .skill(skill)
        )
    }

    static func from(server: MCPServer) -> InventoryItem {
        let pluginScope = server.pluginName != nil ? (server.pluginScope ?? .user).rawValue.capitalized : nil
        let pluginBadge = server.pluginName.map { _ in InventoryBadge(text: "Plugin", style: .orange) }
        let scopeBadge = pluginScope.map {
            InventoryBadge(text: $0, style: badgeStyle(for: server.pluginScope))
        }

        let transportBadge = InventoryBadge(
            text: server.transport.description,
            style: transportBadgeStyle(for: server.transport)
        )

        var availableActions: [InventoryAction] = []
        let primaryURL = server.url.flatMap(URL.init(string:))
        if primaryURL != nil {
            availableActions.append(.openURL)
        }

        return InventoryItem(
            id: server.id,
            kind: .mcp,
            title: server.name,
            subtitle: mcpSubtitle(for: server),
            description: nil,
            isEnabled: server.isEnabled,
            badges: [transportBadge, pluginBadge, scopeBadge].compactMap { $0 },
            sourceLabel: server.pluginName != nil ? "Plugin" : nil,
            scopeLabel: pluginScope,
            primaryLocation: nil,
            secondaryLocation: nil,
            primaryURL: primaryURL,
            availableActions: availableActions,
            primaryAction: primaryURL != nil ? .openURL : nil,
            infoMessage: nil,
            isUserInvocable: nil,
            payload: .mcp(server)
        )
    }

    static func from(agent: AgentProfile) -> InventoryItem {
        let pluginScope = agent.source == .plugin ? (agent.pluginScope ?? .user).rawValue.capitalized : nil
        let pluginBadge = agent.source == .plugin ? InventoryBadge(text: "Plugin", style: .orange) : nil
        let scopeBadge = pluginScope.map {
            InventoryBadge(text: $0, style: badgeStyle(for: agent.pluginScope))
        }

        return InventoryItem(
            id: agent.id,
            kind: .agent,
            title: agent.name,
            subtitle: agent.model.flatMap { $0.isEmpty ? nil : "Model: \($0)" },
            description: agent.description.isEmpty ? nil : agent.description,
            isEnabled: agent.isEnabled,
            badges: [pluginBadge, scopeBadge].compactMap { $0 },
            sourceLabel: agent.source == .plugin ? "Plugin" : nil,
            scopeLabel: pluginScope,
            primaryLocation: agent.path,
            secondaryLocation: nil,
            primaryURL: nil,
            availableActions: [.revealInFinder, .copyPath],
            primaryAction: .revealInFinder,
            infoMessage: nil,
            isUserInvocable: nil,
            payload: .agent(agent)
        )
    }

    private static func marketplaceDisplayName(repo: String?, marketplaceName: String?) -> String? {
        if let repo, !repo.isEmpty {
            return repo
        }
        guard let marketplaceName, !marketplaceName.isEmpty else { return nil }
        return marketplaceName.replacingOccurrences(of: "-marketplace", with: "")
    }

    private static func mcpSubtitle(for server: MCPServer) -> String? {
        switch server.transport {
        case .http, .sse:
            return server.url
        case .stdio:
            var parts = [server.command ?? ""]
            if !server.args.isEmpty {
                parts.append(contentsOf: server.args)
            }
            let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return joined.isEmpty ? nil : joined
        }
    }

    private static func nonToggleableReason(for skill: Skill) -> String {
        if skill.source == .plugin {
            return "Managed by Claude Code's plugin system. Toggle it via `claude plugin enable/disable <name>` or by editing enabledPlugins in your settings.json."
        }
        return "This skill is a regular directory, not a symlink. SkillsBar can only toggle symlink-based skills — the symlink can be safely removed and recreated because the original copy is preserved in .agents/skills/.\n\nTo make it toggleable, install it using the Symlink method via `npx skills add`."
    }

    private static func badgeStyle(for scope: Skill.PluginScope?) -> InventoryBadge.Style {
        switch scope {
        case .user:
            return .blue
        case .project:
            return .green
        case .local:
            return .orange
        case .none:
            return .neutral
        }
    }

    private static func transportBadgeStyle(for transport: MCPTransport) -> InventoryBadge.Style {
        switch transport {
        case .http:
            return .blue
        case .sse:
            return .purple
        case .stdio:
            return .orange
        }
    }
}
