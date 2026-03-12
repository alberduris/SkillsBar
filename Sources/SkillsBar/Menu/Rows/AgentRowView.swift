import SwiftUI

struct AgentRowView: View {
    let item: InventoryItem
    let onPrimaryAction: (InventoryItem) -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var isHovering = false

    private var contentOpacity: Double {
        item.isEnabled ? 1.0 : 0.6
    }

    private var showsStatusIcon: Bool {
        item.badges.contains { $0.text == "Plugin" }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsStatusIcon {
                Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 14))
                    .foregroundStyle(item.isEnabled ? Color.green : Color.secondary)
                    .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                    ForEach(item.badges, id: \.self) { badge in
                        InventoryBadgeView(badge: badge)
                    }

                    Spacer()
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.85))
                }

                if let description = item.description, !description.isEmpty {
                    Text(description)
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
            onPrimaryAction(item)
        }
    }
}
