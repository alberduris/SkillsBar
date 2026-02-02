import SkillsBarCore
import WidgetKit

struct SkillsBarEntry: TimelineEntry {
    let date: Date
    let skills: [SkillSnapshot]
    let totalCount: Int
    let globalCount: Int
    let pluginCount: Int
    let projectCount: Int
}

struct SkillSnapshot: Identifiable {
    let id: String
    let name: String
    let source: SkillSource
}

struct SkillsBarTimelineProvider: TimelineProvider {
    typealias Entry = SkillsBarEntry

    func placeholder(in context: Context) -> SkillsBarEntry {
        SkillsBarEntry(
            date: Date(),
            skills: [
                SkillSnapshot(id: "1", name: "commit", source: .global),
                SkillSnapshot(id: "2", name: "review-pr", source: .plugin),
            ],
            totalCount: 5,
            globalCount: 2,
            pluginCount: 2,
            projectCount: 1
        )
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SkillsBarEntry) -> Void) {
        Task { @MainActor in
            let entry = await loadEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SkillsBarEntry>) -> Void) {
        Task { @MainActor in
            let entry = await loadEntry()
            // Refresh every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    private func loadEntry() async -> SkillsBarEntry {
        let discovery = SkillsDiscovery.forClaudeCode()
        let skills = await discovery.discoverAll()

        let snapshots = skills.prefix(10).map { skill in
            SkillSnapshot(id: skill.id, name: skill.name, source: skill.source)
        }

        let bySource = Dictionary(grouping: skills, by: \.source)

        return SkillsBarEntry(
            date: Date(),
            skills: Array(snapshots),
            totalCount: skills.count,
            globalCount: bySource[.global]?.count ?? 0,
            pluginCount: bySource[.plugin]?.count ?? 0,
            projectCount: bySource[.project]?.count ?? 0
        )
    }
}
