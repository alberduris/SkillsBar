import SkillsBarCore
import SwiftUI

struct SkillsMenuCardView: View {
    @Bindable var skillsStore: SkillsStore
    let onRefresh: () -> Void
    let onOpenLibrary: () -> Void
    let onOpenSettings: () -> Void
    let width: CGFloat

    @State private var viewModel: InventoryViewModel

    init(
        skillsStore: SkillsStore,
        onRefresh: @escaping () -> Void,
        onOpenLibrary: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        width: CGFloat
    ) {
        self.skillsStore = skillsStore
        self.onRefresh = onRefresh
        self.onOpenLibrary = onOpenLibrary
        self.onOpenSettings = onOpenSettings
        self.width = width
        _viewModel = State(initialValue: InventoryViewModel(skillsStore: skillsStore))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 6) {
            MenuHeaderView(
                skillsStore: skillsStore,
                onOpenLibrary: onOpenLibrary,
                onRefresh: onRefresh
            )

            Divider()

            Picker("", selection: $viewModel.selectedTab) {
                Text("Skills (\(skillsStore.totalCount))").tag(InventoryTab.skills)
                Text("MCPs (\(skillsStore.mcpCount))").tag(InventoryTab.mcps)
                Text("Agents (\(skillsStore.agentCount))").tag(InventoryTab.agents)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            MenuFilterBarView(filterText: $viewModel.filterText)

            ScrollView {
                contentView
            }
            .frame(height: 480)

            Divider()

            MenuFooterView(onOpenSettings: onOpenSettings)
        }
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.selectedTab {
        case .skills:
            if skillsStore.skills.isEmpty {
                MenuEmptyStateView(
                    icon: "sparkles",
                    title: "No skills found",
                    message: "Add skills to ~/.claude/skills/ or <project>/.claude/skills/"
                )
            } else {
                sectionsContent
            }
        case .mcps:
            if skillsStore.hasMCPServers {
                sectionsContent
            } else {
                MenuEmptyStateView(
                    icon: "server.rack",
                    title: "No MCP servers found",
                    message: "Configure MCPs in ~/.claude.json or .mcp.json"
                )
            }
        case .agents:
            if skillsStore.hasAgents {
                sectionsContent
            } else {
                MenuEmptyStateView(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "No agents found",
                    message: "Install plugin agents from Claude Code plugins"
                )
            }
        }
    }

    private var sectionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.sections) { section in
                InventorySectionView(
                    section: section,
                    actionHandler: viewModel.actionHandler,
                    onPrimaryAction: { item in
                        viewModel.performPrimaryAction(for: item)
                    },
                    onAction: { action, item in
                        viewModel.perform(action, on: item)
                    }
                )
            }

            if viewModel.showsNoMatchesState {
                MenuEmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No matching projects",
                    message: nil
                )
            }
        }
        .padding(.vertical, 6)
    }
}
