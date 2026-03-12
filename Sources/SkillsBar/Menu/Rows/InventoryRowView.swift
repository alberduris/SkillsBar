import SwiftUI

struct InventoryRowView: View {
    let item: InventoryItem
    let actionHandler: InventoryActionHandler
    let onPrimaryAction: (InventoryItem) -> Void
    let onAction: (InventoryAction, InventoryItem) -> Void

    var body: some View {
        switch item.payload {
        case .skill:
            SkillRowView(
                item: item,
                actionHandler: actionHandler,
                onPrimaryAction: onPrimaryAction,
                onAction: onAction
            )
        case .mcp:
            MCPRowView(
                item: item,
                onPrimaryAction: onPrimaryAction
            )
        case .agent:
            AgentRowView(
                item: item,
                onPrimaryAction: onPrimaryAction
            )
        }
    }
}
