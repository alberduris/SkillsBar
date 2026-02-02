import SkillsBarCore
import SwiftUI
import WidgetKit

struct SkillsBarWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: SkillsBarEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: SkillsBarEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("Skills")
                    .font(.headline)
            }

            Spacer()

            HStack(spacing: 16) {
                CountBadge(count: entry.globalCount, label: "Global", color: .blue)
                CountBadge(count: entry.pluginCount, label: "Plugin", color: .purple)
            }

            Spacer()

            Text("\(entry.totalCount) total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: SkillsBarEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side: counts
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                    Text("Skills")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    CountRow(count: entry.globalCount, label: "Global", icon: "globe", color: .blue)
                    CountRow(count: entry.pluginCount, label: "Plugin", icon: "puzzlepiece.extension", color: .purple)
                    CountRow(count: entry.projectCount, label: "Project", icon: "folder", color: .orange)
                }

                Spacer()

                Text("\(entry.totalCount) total skills")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Right side: skill list
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(entry.skills.prefix(5)) { skill in
                    HStack(spacing: 4) {
                        Image(systemName: skill.source.sfSymbolName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(skill.name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

                if entry.skills.isEmpty {
                    Text("No skills found")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

// MARK: - Helper Views

struct CountBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct CountRow: View {
    let count: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

