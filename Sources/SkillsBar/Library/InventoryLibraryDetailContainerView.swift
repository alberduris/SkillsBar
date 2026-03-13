import SwiftUI

struct InventoryLibraryDetailContainerView: View {
    @Bindable var viewModel: InventoryViewModel

    var body: some View {
        Group {
            if let item = viewModel.selectedItem {
                InventoryDetailView(item: item, actionHandler: viewModel.actionHandler)
            } else {
                InventoryEmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InventoryEmptyDetailView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Select a resource")
                .font(.title3.weight(.semibold))
            Text("The detail panel will show structured information, file locations, and actions for the selected item.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct InventoryDetailView: View {
    let item: InventoryItem
    let actionHandler: InventoryActionHandler

    var body: some View {
        switch item.payload {
        case .skill(let skill):
            SkillDetailView(item: item, skill: skill, actionHandler: actionHandler)
        case .mcp(let server):
            MCPDetailView(item: item, server: server, actionHandler: actionHandler)
        case .agent(let agent):
            AgentDetailView(item: item, agent: agent, actionHandler: actionHandler)
        }
    }
}
