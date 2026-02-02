import SwiftUI
import WidgetKit

@main
struct SkillsBarWidgetBundle: WidgetBundle {
    var body: some Widget {
        SkillsBarWidget()
    }
}

struct SkillsBarWidget: Widget {
    private let kind = "SkillsBarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SkillsBarTimelineProvider()) { entry in
            SkillsBarWidgetView(entry: entry)
        }
        .configurationDisplayName("Skills")
        .description("Shows your AI coding agent skills.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
