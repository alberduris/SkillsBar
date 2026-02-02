import AppKit
import SkillsBarCore
import SwiftUI

// MARK: - Agents Pane

struct AgentsPane: View {
    @Bindable var settings: SettingsStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Coding Agents")
                        .font(.headline)
                    Text("Enable agents to discover skills for. More agents coming soon!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Active Agents Section
                if !AgentRegistry.supported.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AgentRegistry.supported) { agent in
                                AgentCard(
                                    agent: agent,
                                    isEnabled: settings.isAgentEnabled(agent),
                                    onToggle: { settings.setAgentEnabled(agent, enabled: $0) }
                                )
                            }
                        }
                    }
                }

                // Coming Soon Section
                if !AgentRegistry.planned.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Coming Soon", systemImage: "clock.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(AgentRegistry.planned) { agent in
                                AgentCard(
                                    agent: agent,
                                    isEnabled: false,
                                    onToggle: nil
                                )
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Agent Card

private struct AgentCard: View {
    let agent: Agent
    let isEnabled: Bool
    let onToggle: ((Bool) -> Void)?

    @State private var isHovering = false

    private var isInteractive: Bool {
        onToggle != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Icon
                AgentIcon(agent: agent)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(agent.displayName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)

                        if agent.status == .comingSoon {
                            ComingSoonBadge()
                        }
                    }

                    if !agent.tagline.isEmpty {
                        Text(agent.tagline)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isInteractive {
                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { onToggle?($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(cardBorder, lineWidth: 1)
                }
        }
        .opacity(isInteractive ? 1.0 : 0.6)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            if let url = agent.websiteURL.flatMap({ URL(string: $0) }) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private var cardBackground: Color {
        if isHovering && isInteractive {
            return Color(nsColor: .controlBackgroundColor).opacity(0.8)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.5)
    }

    private var cardBorder: Color {
        if isEnabled && isInteractive {
            return agent.accentColor.opacity(0.5)
        }
        return Color(nsColor: .separatorColor).opacity(0.3)
    }
}

// MARK: - Agent Icon

private struct AgentIcon: View {
    let agent: Agent

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(agent.accentColor.gradient)

            if let image = loadSVGIcon() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            } else {
                // Fallback: first letter
                Text(String(agent.displayName.prefix(1)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private func loadSVGIcon() -> NSImage? {
        let iconName = "ProviderIcon-\(agent.iconName)"

        // Try to load from bundle resources
        if let url = Bundle.main.url(forResource: iconName, withExtension: "svg"),
           let image = NSImage(contentsOf: url)
        {
            return image
        }

        // Try module bundle (for SPM)
        #if SWIFT_PACKAGE
        if let url = Bundle.module.url(forResource: iconName, withExtension: "svg"),
           let image = NSImage(contentsOf: url)
        {
            return image
        }
        #endif

        return nil
    }
}

// MARK: - Coming Soon Badge

private struct ComingSoonBadge: View {
    var body: some View {
        Text("Soon")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(Color.secondary.opacity(0.6))
            }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AgentsPane(settings: SettingsStore())
        .frame(width: 400, height: 500)
        .padding()
}
#endif
