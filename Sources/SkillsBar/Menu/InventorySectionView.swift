import SwiftUI

struct InventorySectionView: View {
    let section: InventorySection
    let actionHandler: InventoryActionHandler
    let onPrimaryAction: (InventoryItem) -> Void
    let onAction: (InventoryAction, InventoryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuSectionHeaderView(
                title: section.title,
                icon: section.icon,
                trailingText: section.trailingText
            )

            if let note = section.note {
                InventorySectionNoteView(note: note)
            }

            ForEach(section.items.prefix(8)) { item in
                InventoryRowView(
                    item: item,
                    actionHandler: actionHandler,
                    onPrimaryAction: onPrimaryAction,
                    onAction: onAction
                )
            }

            if section.items.count > 8 {
                InventoryOverflowView(overflowCount: section.items.count - 8)
            }
        }
    }
}

private struct InventorySectionNoteView: View {
    let note: String

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        Text(note)
            .font(.system(size: 10))
            .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.55))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
    }
}

private struct InventoryOverflowView: View {
    let overflowCount: Int

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        Text("... and \(overflowCount) more")
            .font(.footnote)
            .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
    }
}
