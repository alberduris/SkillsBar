import SwiftUI

struct MCPRowView: View {
    let item: InventoryItem
    let onPrimaryAction: (InventoryItem) -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var isHovering = false

    private var contentOpacity: Double {
        item.isEnabled ? 1.0 : 0.6
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.isEnabled ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 14))
                .foregroundStyle(item.isEnabled ? Color.green : Color.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                    ForEach(item.badges, id: \.self) { badge in
                        if badge.text == "HTTP" || badge.text == "SSE" || badge.text == "stdio" {
                            MCPTransportBadgeView(badge: badge)
                        } else {
                            InventoryBadgeView(badge: badge)
                        }
                    }

                    Spacer()
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
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

private struct MCPTransportBadgeView: View {
    let badge: InventoryBadge

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(badge.text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private var color: Color {
        switch badge.style {
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .orange:
            return .orange
        case .neutral:
            return .secondary
        case .green:
            return .green
        }
    }
}
