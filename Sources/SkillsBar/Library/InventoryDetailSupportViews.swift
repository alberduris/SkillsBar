import SwiftUI

struct InventoryDetailScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct InventoryDetailHeroView: View {
    let item: InventoryItem
    let statusText: String
    let trailingInfo: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.largeTitle.weight(.semibold))
                    if let description = item.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 16)

                if let trailingInfo {
                    Text(trailingInfo)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((item.isEnabled ? Color.green : Color.secondary).opacity(0.14))
                    .foregroundStyle(item.isEnabled ? Color.green : Color.secondary)
                    .clipShape(Capsule())

                ForEach(item.badges, id: \.self) { badge in
                    InventoryBadgeView(badge: badge)
                }
            }
        }
    }
}

struct InventoryDetailSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            )
        }
    }
}

struct InventoryDetailField: View {
    let label: String
    let value: String
    var monospaced = false
    var multiline = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: multiline)
        }
    }
}

struct InventoryActionButtonsView: View {
    let item: InventoryItem
    let actionHandler: InventoryActionHandler
    @Binding var showingInfo: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(item.availableActions, id: \.self) { action in
                Button {
                    if action == .showInfo {
                        showingInfo.toggle()
                    } else {
                        actionHandler.perform(action, on: item)
                    }
                } label: {
                    Label(label(for: action), systemImage: icon(for: action))
                }
                .buttonStyle(.borderedProminent)
                .tint(tint(for: action))
            }
        }
        .buttonBorderShape(.capsule)
    }

    private func label(for action: InventoryAction) -> String {
        switch action {
        case .toggleEnabled:
            return item.isEnabled ? "Disable" : "Enable"
        case .revealInFinder:
            return "Reveal"
        case .openURL:
            return "Open"
        case .copyPath:
            return "Copy"
        case .showInfo:
            return "Info"
        }
    }

    private func icon(for action: InventoryAction) -> String {
        switch action {
        case .toggleEnabled:
            return item.isEnabled ? "pause.circle" : "play.circle"
        case .revealInFinder:
            return "folder"
        case .openURL:
            return "arrow.up.right.square"
        case .copyPath:
            return "doc.on.doc"
        case .showInfo:
            return "info.circle"
        }
    }

    private func tint(for action: InventoryAction) -> Color {
        switch action {
        case .toggleEnabled:
            return item.isEnabled ? .orange : .green
        case .revealInFinder:
            return .blue
        case .openURL:
            return .blue
        case .copyPath:
            return .secondary
        case .showInfo:
            return .secondary
        }
    }
}

struct InventoryInfoCalloutView: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }
}
