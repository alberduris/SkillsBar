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

/// Main card view for the skills menu.
struct SkillsMenuCardView: View {
    let skillsStore: SkillsStore
    let onRefresh: () -> Void
    let onOpenSettings: () -> Void
    let width: CGFloat

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            headerSection

            Divider()

            // Skills content
            if skillsStore.skills.isEmpty && !skillsStore.hasMCPServers {
                emptyState
            } else if !skillsStore.skills.isEmpty {
                skillsList
            }

            // MCP servers section
            if skillsStore.hasMCPServers {
                if !skillsStore.skills.isEmpty {
                    Divider()
                }
                mcpList
            }

            Divider()

            // Footer
            footerSection
        }
        .frame(width: width, alignment: .leading)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.title)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("No skills found")
                .font(.subheadline)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

            Text("Add skills to ~/.claude/skills/")
                .font(.footnote)
                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Skills List

    private var skillsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Global skills
            if let globalSkills = skillsStore.skillsBySource[.global], !globalSkills.isEmpty {
                SkillSourceSectionView(source: .global, skills: globalSkills, projectName: nil)
            }

            // Plugin skills
            if let pluginSkills = skillsStore.skillsBySource[.plugin], !pluginSkills.isEmpty {
                SkillSourceSectionView(source: .plugin, skills: pluginSkills, projectName: nil)
            }

            // Project skills - grouped by project
            if let projectSkills = skillsStore.skillsBySource[.project], !projectSkills.isEmpty {
                let groupedByProject = Dictionary(grouping: projectSkills) { skill in
                    projectDisplayName(for: skill.projectRoot)
                }
                ForEach(groupedByProject.keys.sorted(), id: \.self) { projectName in
                    if let skills = groupedByProject[projectName] {
                        SkillSourceSectionView(source: .project, skills: skills, projectName: projectName)
                    }
                }
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
                        ForEach(groupedByProject.keys.sorted(), id: \.self) { projectName in
                            if let projectServers = groupedByProject[projectName] {
                                MCPSourceSectionView(source: source, servers: projectServers, projectName: projectName)
                            }
                        }
                    } else {
                        MCPSourceSectionView(source: source, servers: servers, projectName: nil)
                    }
                }
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
}

// MARK: - Source Section

private struct SkillSourceSectionView: View {
    let source: SkillSource
    let skills: [Skill]
    let projectName: String?

    @Environment(\.menuItemHighlighted) private var isHighlighted

    private var sectionTitle: String {
        if let projectName, source == .project {
            return projectName
        }
        return source.displayName
    }

    private var enabledCount: Int {
        skills.filter(\.isEnabled).count
    }

    private var countLabel: String {
        if source == .plugin && enabledCount < skills.count {
            return "(\(enabledCount)/\(skills.count))"
        }
        return "(\(skills.count))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: source.sfSymbolName)
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                Text(sectionTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                Text(countLabel)
                    .font(.caption)
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
                // Line 1: Skill name
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                    Spacer()

                    if !skill.isUserInvocable {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
                    }
                }

                // Line 2: Marketplace repo as colored pill (for plugin skills)
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
        return source.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 6) {
                Image(systemName: source == .builtIn ? source.sfSymbolName : "server.rack")
                    .font(.caption)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                Text(sectionTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))

                if source == .builtIn {
                    Text("always available")
                        .font(.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.5))
                } else {
                    Text("(\(servers.count))")
                        .font(.caption)
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

                    Text(server.transport.description)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(transportColor.opacity(0.15))
                        .foregroundStyle(transportColor)
                        .clipShape(Capsule())

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
