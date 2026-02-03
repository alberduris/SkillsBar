import AppKit
import SkillsBarCore
import SwiftUI

// MARK: - Button Styles

private struct MenuButtonStyle: ButtonStyle {
    let isHighlighted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(MenuHighlightStyle.secondary(isHighlighted).opacity(configuration.isPressed ? 0.18 : 0))
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tab selector for the menu card content area.
enum MenuTab: String, CaseIterable {
    case skills
    case mcps
    case agents
}

/// Main card view for the skills menu.
struct SkillsMenuCardView: View {
    @Bindable var skillsStore: SkillsStore
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void
    let width: CGFloat

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var selectedTab: MenuTab = .skills
    @State private var filterText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            headerSection

            Divider()

            // Segmented control
            Picker("", selection: $selectedTab) {
                Text("Skills (\(skillsStore.totalCount))").tag(MenuTab.skills)
                Text("MCPs (\(skillsStore.mcpCount))").tag(MenuTab.mcps)
                Text("Agents (\(skillsStore.agentCount))").tag(MenuTab.agents)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            filterBar

            // Tab content in scrollable area with fixed height.
            // NSMenu items have a fixed frame — without a constant-height
            // container, switching tabs causes the menu to freeze.
            ScrollView {
                switch selectedTab {
                case .skills:
                    if skillsStore.skills.isEmpty {
                        emptyState
                    } else {
                        skillsList
                    }
                case .mcps:
                    if skillsStore.hasMCPServers {
                        mcpList
                    } else {
                        emptyMCPState
                    }
                case .agents:
                    if skillsStore.hasAgents {
                        agentsList
                    } else {
                        emptyAgentsState
                    }
                }
            }
            .frame(height: 480)

            Divider()

            // Footer
            footerSection
        }
        .frame(width: width, alignment: .leading)
    }

    // MARK: - Filter

    private var filterQuery: String {
        filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isFiltering: Bool {
        !filterQuery.isEmpty
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            TextField("Filter projects", text: $filterText)
                .textFieldStyle(.plain)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
                )
                .disableAutocorrection(true)

            if !filterText.isEmpty {
                Button(action: { filterText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("SkillsBar")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                Spacer()

                if skillsStore.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
                    }
                    .buttonStyle(MenuButtonStyle(isHighlighted: isHighlighted))
                }
            }

            HStack {
                let enabledCount = skillsStore.skills.filter(\.isEnabled).count
                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                if enabledCount < skillsStore.totalCount {
                    Text("(\(enabledCount) enabled)")
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
                }

                Spacer()

                if let lastRefresh = skillsStore.lastRefreshTime {
                    Text(relativeTimeString(from: lastRefresh))
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("No skills found")
                .font(.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("Add skills to ~/.claude/skills/ or <project>/.claude/skills/")
                .font(.footnote)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var emptyMCPState: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.title)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("No MCP servers found")
                .font(.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("Configure MCPs in ~/.claude.json or .mcp.json")
                .font(.footnote)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var emptyAgentsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("No agents found")
                .font(.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("Install plugin agents from Claude Code plugins")
                .font(.footnote)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var noMatchesState: some View {
        VStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("No matching projects")
                .font(.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Skills List

    private var skillsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // All-projects skills (includes user-scoped plugin skills)
            let globalSkills = skillsStore.skills.filter { skill in
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
                SkillScopeSectionView(
                    title: "All Projects",
                    icon: "globe",
                    skills: globalSkills.sorted()
                )
            }

            // Project skills + project/local scoped plugin skills, grouped by project
            let projectScopedSkills = skillsStore.skills.filter { skill in
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
                if !isFiltering { return true }
                return projectName.lowercased().contains(filterQuery)
            }
            ForEach(visibleProjectNames, id: \.self) { projectName in
                if let skills = groupedByProject[projectName] {
                    SkillScopeSectionView(title: projectName, icon: "folder", skills: skills.sorted())
                }
            }

            if isFiltering && visibleProjectNames.isEmpty {
                noMatchesState
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button(action: onOpenSettings) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                    Text("Settings")
                        .font(.subheadline)
                }
                .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))
            }
            .buttonStyle(MenuButtonStyle(isHighlighted: isHighlighted))

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Text("Quit")
                    .font(.subheadline)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
            }
            .buttonStyle(MenuButtonStyle(isHighlighted: isHighlighted))
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    // MARK: - MCP List

    private var mcpList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(MCPSource.allCases, id: \.self) { source in
                if let servers = skillsStore.mcpServersBySource[source], !servers.isEmpty {
                    if source == .project {
                        // Group project servers by project name
                        let groupedByProject = Dictionary(grouping: servers) { $0.projectName ?? "Unknown" }
                        let visibleProjectNames = groupedByProject.keys.sorted().filter { projectName in
                            if !isFiltering { return true }
                            return projectName.lowercased().contains(filterQuery)
                        }
                        ForEach(visibleProjectNames, id: \.self) { projectName in
                            if let projectServers = groupedByProject[projectName] {
                                MCPSourceSectionView(source: source, servers: projectServers, projectName: projectName)
                            }
                        }
                    } else {
                        MCPSourceSectionView(source: source, servers: servers, projectName: nil)
                    }
                }
            }

            if isFiltering && !mcpHasVisibleResults() {
                noMatchesState
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private var headerSubtitle: String {
        var parts: [String] = []
        if skillsStore.totalCount > 0 {
            parts.append("\(skillsStore.totalCount) skills")
        }
        if skillsStore.mcpCount > 0 {
            parts.append("\(skillsStore.mcpCount) MCPs")
        }
        if skillsStore.agentCount > 0 {
            parts.append("\(skillsStore.agentCount) agents")
        }
        if parts.isEmpty {
            return "0 skills"
        }
        return parts.joined(separator: ", ")
    }

    /// Returns "parent/project" display name for project root URL
    private func projectDisplayName(for projectRoot: URL?) -> String {
        guard let root = projectRoot else { return "Unknown" }
        let project = root.lastPathComponent
        let parent = root.deletingLastPathComponent().lastPathComponent
        if !parent.isEmpty && parent != "/" {
            return "\(parent)/\(project)"
        }
        return project
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        }
    }

    private func mcpHasVisibleResults() -> Bool {
        for source in MCPSource.allCases {
            guard let servers = skillsStore.mcpServersBySource[source], !servers.isEmpty else { continue }
            if source == .project {
                let groupedByProject = Dictionary(grouping: servers) { $0.projectName ?? "Unknown" }
                for (projectName, _) in groupedByProject {
                    if projectName.lowercased().contains(filterQuery) { return true }
                }
            } else {
                continue
            }
        }
        return false
    }
}

// MARK: - Agents List

private extension SkillsMenuCardView {
    var agentsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // All-projects agents (includes user-scoped plugin agents)
            let globalAgents = skillsStore.agents.filter { agent in
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
                AgentScopeSectionView(
                    title: "All Projects",
                    icon: "globe",
                    agents: globalAgents.sorted()
                )
            }

            // Project agents + project/local scoped plugin agents, grouped by project
            let projectScopedAgents = skillsStore.agents.filter { agent in
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
                if !isFiltering { return true }
                return projectName.lowercased().contains(filterQuery)
            }
            ForEach(visibleProjectNames, id: \.self) { projectName in
                if let agents = groupedByProject[projectName] {
                    AgentScopeSectionView(title: projectName, icon: "folder", agents: agents.sorted())
                }
            }

            if isFiltering && visibleProjectNames.isEmpty {
                noMatchesState
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Scope Section

private struct SkillScopeSectionView: View {
    let title: String
    let icon: String
    let skills: [Skill]

    @Environment(\.menuItemHighlighted) private var isHighlighted

    private var enabledCount: Int {
        skills.filter(\.isEnabled).count
    }

    private var countLabel: String {
        if enabledCount < skills.count {
            return "(\(enabledCount)/\(skills.count))"
        }
        return "(\(skills.count))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                SectionTitleView(title: title, isHighlighted: isHighlighted)

                Text(countLabel)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(MenuHighlightStyle.progressTrack(isHighlighted).opacity(0.5))

            // Skills
            ForEach(skills.prefix(8)) { skill in
                SkillRowView(skill: skill)
            }

            if skills.count > 8 {
                Text("... and \(skills.count - 8) more")
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Section Title

private struct SectionTitleView: View {
    let title: String
    let isHighlighted: Bool

    private var baseColor: Color {
        MenuHighlightStyle.secondary(isHighlighted)
    }

    var body: some View {
        let parts = title.split(separator: "/").map(String.init)
        if parts.count >= 2 {
            let folder = parts.last ?? title
            let parent = parts.dropLast().joined(separator: "/")
            HStack(spacing: 0) {
                Text(parent + "/")
                    .font(.callout)
                    .foregroundStyle(baseColor.opacity(0.6))
                Text(folder)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(baseColor)
            }
        } else {
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(baseColor)
        }
    }
}

// MARK: - Skill Row

private struct SkillRowView: View {
    let skill: Skill

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var isHovering = false

    /// Opacity for disabled skills (not too faded)
    private var contentOpacity: Double {
        skill.isEnabled ? 1.0 : 0.6
    }

    /// Get display name for marketplace - prefer repo (user/repo) over internal name
    private var marketplaceDisplayName: String {
        if let repo = skill.marketplaceRepo {
            return repo
        }
        if let name = skill.marketplaceName {
            return name.replacingOccurrences(of: "-marketplace", with: "")
        }
        return ""
    }

    private var pluginScope: Skill.PluginScope? {
        guard skill.source == .plugin else { return nil }
        return skill.pluginScope ?? .user
    }

    private var originLabel: String? {
        switch skill.source {
        case .plugin:
            return "Plugin"
        case .global, .project:
            return "Direct"
        }
    }

    private var originColor: Color {
        switch skill.source {
        case .plugin:
            return .orange
        case .global, .project:
            return .secondary
        }
    }

    private var pluginScopeColor: Color {
        switch pluginScope {
        case .user:
            return .blue
        case .project:
            return .green
        case .local:
            return .orange
        case .none:
            return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Enabled/disabled indicator for plugin skills
            if skill.source == .plugin {
                Image(systemName: skill.isEnabled ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 14))
                    .foregroundStyle(skill.isEnabled ? Color.green : Color.secondary)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Line 1: Skill name + origin badges
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                    if let originLabel {
                        Text(originLabel)
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(originColor.opacity(0.15))
                            .foregroundStyle(originColor)
                            .clipShape(Capsule())

                        if let scope = pluginScope {
                            Text(scope.rawValue.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(pluginScopeColor.opacity(0.15))
                                .foregroundStyle(pluginScopeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    if !skill.isUserInvocable {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
                    }
                }

                // Line 2: Marketplace repo (for plugin skills)
                if skill.source == .plugin && !marketplaceDisplayName.isEmpty {
                    Text(marketplaceDisplayName)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor.opacity(0.9))
                }

                // Line 3: Description
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .opacity(contentOpacity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .padding(.horizontal, 6)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([skill.path])
        }
    }
}

// MARK: - MCP Source Section

private struct MCPSourceSectionView: View {
    let source: MCPSource
    let servers: [MCPServer]
    let projectName: String?

    @Environment(\.menuItemHighlighted) private var isHighlighted

    private var sectionTitle: String {
        if let projectName, source == .project {
            return projectName
        }
        if source == .global {
            return "All Projects"
        }
        return source.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: source == .builtIn ? source.sfSymbolName : "server.rack")
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                SectionTitleView(title: sectionTitle, isHighlighted: isHighlighted)

                if source == .builtIn {
                    Text("always available")
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.5))
                } else {
                    Text("(\(servers.count))")
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(MenuHighlightStyle.progressTrack(isHighlighted).opacity(0.5))

            // Built-in explanation
            if source == .builtIn {
                Text("Runtime MCPs managed by Claude Code. Status reflects default config, not live connections.")
                    .font(.system(size: 10))
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.55))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            // Servers
            ForEach(servers.prefix(8)) { server in
                MCPServerRowView(server: server)
            }

            if servers.count > 8 {
                Text("... and \(servers.count - 8) more")
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - MCP Server Row

private struct MCPServerRowView: View {
    let server: MCPServer

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var isHovering = false

    private var contentOpacity: Double {
        server.isEnabled ? 1.0 : 0.6
    }

    private var transportColor: Color {
        switch server.transport {
        case .http: return .blue
        case .sse: return .purple
        case .stdio: return .orange
        }
    }

    private var pluginScope: Skill.PluginScope? {
        guard server.pluginName != nil else { return nil }
        return server.pluginScope ?? .user
    }

    private var pluginScopeColor: Color {
        switch pluginScope {
        case .user:
            return .blue
        case .project:
            return .green
        case .local:
            return .orange
        case .none:
            return .secondary
        }
    }

    private var detailText: String {
        switch server.transport {
        case .http, .sse:
            if let url = server.url {
                // Truncate long URLs
                if url.count > 40 {
                    return String(url.prefix(37)) + "..."
                }
                return url
            }
            return ""
        case .stdio:
            var parts = [server.command ?? ""]
            if !server.args.isEmpty {
                parts.append(contentsOf: server.args.prefix(2))
                if server.args.count > 2 {
                    parts.append("...")
                }
            }
            let joined = parts.joined(separator: " ")
            if joined.count > 45 {
                return String(joined.prefix(42)) + "..."
            }
            return joined
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Enabled/disabled indicator
            Image(systemName: server.isEnabled ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 14))
                .foregroundStyle(server.isEnabled ? Color.green : Color.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                // Line 1: Server name + transport badge
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(transportColor)
                            .frame(width: 6, height: 6)
                        Text(server.transport.description)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(transportColor)
                    }

                    if server.pluginName != nil {
                        Text("Plugin")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(Color.orange)
                            .clipShape(Capsule())

                        if let scope = pluginScope {
                            Text(scope.rawValue.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(pluginScopeColor.opacity(0.15))
                                .foregroundStyle(pluginScopeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }

                // Line 2: URL or command
                if !detailText.isEmpty {
                    Text(detailText)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .opacity(contentOpacity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .padding(.horizontal, 6)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            // For http/sse, open URL in browser
            if let urlString = server.url, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Agent Scope Section

private struct AgentScopeSectionView: View {
    let title: String
    let icon: String
    let agents: [AgentProfile]

    @Environment(\.menuItemHighlighted) private var isHighlighted

    private var enabledCount: Int {
        agents.filter(\.isEnabled).count
    }

    private var countLabel: String {
        if enabledCount < agents.count {
            return "(\(enabledCount)/\(agents.count))"
        }
        return "(\(agents.count))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                SectionTitleView(title: title, isHighlighted: isHighlighted)

                Text(countLabel)
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(MenuHighlightStyle.progressTrack(isHighlighted).opacity(0.5))

            // Agents
            ForEach(agents.prefix(8)) { agent in
                AgentRowView(agent: agent)
            }

            if agents.count > 8 {
                Text("... and \(agents.count - 8) more")
                    .font(.footnote)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Agent Row

private struct AgentRowView: View {
    let agent: AgentProfile

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var isHovering = false

    private var contentOpacity: Double {
        agent.isEnabled ? 1.0 : 0.6
    }

    private var pluginScope: Skill.PluginScope? {
        guard agent.source == .plugin else { return nil }
        return agent.pluginScope ?? .user
    }

    private var pluginScopeColor: Color {
        switch pluginScope {
        case .user:
            return .blue
        case .project:
            return .green
        case .local:
            return .orange
        case .none:
            return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if agent.source == .plugin {
                Image(systemName: agent.isEnabled ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 14))
                    .foregroundStyle(agent.isEnabled ? Color.green : Color.secondary)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(agent.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                    if agent.source == .plugin {
                        Text("Plugin")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(Color.orange)
                            .clipShape(Capsule())

                        if let scope = pluginScope {
                            Text(scope.rawValue.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(pluginScopeColor.opacity(0.15))
                                .foregroundStyle(pluginScopeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()
                }

                if let model = agent.model, !model.isEmpty {
                    Text("Model: \(model)")
                        .font(.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.85))
                }

                if !agent.description.isEmpty {
                    Text(agent.description)
                        .font(.footnote)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .opacity(contentOpacity)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .padding(.horizontal, 6)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            NSWorkspace.shared.activateFileViewerSelecting([agent.path])
        }
    }
}
