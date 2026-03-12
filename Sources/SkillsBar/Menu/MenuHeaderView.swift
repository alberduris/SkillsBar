import SwiftUI

struct MenuHeaderView: View {
    @Bindable var skillsStore: SkillsStore
    let onRefresh: () -> Void

    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("SkillsBar")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(MenuHighlightStyle.primary(isHighlighted))

                Spacer()

                Group {
                    if skillsStore.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.5)
                    } else {
                        Button(action: onRefresh) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(MenuHighlightStyle.secondary(isHighlighted))
                        }
                        .buttonStyle(MenuButtonStyle(isHighlighted: isHighlighted))
                    }
                }
                .frame(width: 24, height: 24)
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
        return parts.isEmpty ? "0 skills" : parts.joined(separator: ", ")
    }

    private func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        }
        if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        }
        return "\(Int(interval / 3600))h ago"
    }
}
