import SwiftUI

struct SkillRowView: View {
    let item: InventoryItem
    let actionHandler: InventoryActionHandler
    let onPrimaryAction: (InventoryItem) -> Void
    let onAction: (InventoryAction, InventoryItem) -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted
    @State private var showingInfoPopover = false

    private var contentOpacity: Double {
        item.isEnabled ? 1.0 : 0.6
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            SkillToggleIcon(
                isEnabled: item.isEnabled,
                isToggleable: item.availableActions.contains(.toggleEnabled),
                isToggling: actionHandler.isToggling(item.id)
            )

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

                    if item.isUserInvocable == false {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.7))
                    }

                    if item.availableActions.contains(.showInfo) {
                        Button(action: {
                            onAction(.showInfo, item)
                            showingInfoPopover.toggle()
                        }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showingInfoPopover, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Not toggleable")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(item.infoMessage ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(width: 240)
                        }
                    }

                    if item.availableActions.contains(.revealInFinder) {
                        Button(action: { onAction(.revealInFinder, item) }) {
                            Image(systemName: "folder")
                                .font(.caption)
                                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted).opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor.opacity(0.9))
                        .lineLimit(1)
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
        .contentShape(Rectangle())
        .onTapGesture {
            onPrimaryAction(item)
        }
    }
}

private struct SkillToggleIcon: View {
    let isEnabled: Bool
    let isToggleable: Bool
    let isToggling: Bool

    private var iconName: String {
        if isToggling {
            return "circle.dotted"
        }
        return isEnabled ? "checkmark.circle.fill" : "circle.dashed"
    }

    private var iconColor: Color {
        if isToggling {
            return .secondary
        }
        if !isToggleable {
            return isEnabled ? .green.opacity(0.5) : .secondary.opacity(0.4)
        }
        return isEnabled ? .green : .secondary
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 14))
            .foregroundStyle(iconColor)
            .frame(width: 18, height: 18)
            .padding(.top, 1)
    }
}
