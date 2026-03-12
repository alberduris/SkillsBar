import Foundation
import Observation

@MainActor @Observable
final class InventoryViewModel {
    let skillsStore: SkillsStore
    let actionHandler: InventoryActionHandler

    var selectedTab: InventoryTab = .skills {
        didSet {
            rebuild()
        }
    }

    var filterText = "" {
        didSet {
            rebuild()
        }
    }

    var selectedItemID: String?
    private(set) var currentContent: InventoryTabContent

    init(skillsStore: SkillsStore) {
        self.skillsStore = skillsStore
        self.actionHandler = InventoryActionHandler(skillsStore: skillsStore)
        self.currentContent = InventorySectionsBuilder.buildContent(
            for: .skills,
            snapshot: InventorySnapshot(
                skills: skillsStore.skills,
                mcpServers: skillsStore.mcpServers,
                agents: skillsStore.agents
            ),
            filterText: ""
        )
        observeStore()
    }

    var sections: [InventorySection] {
        currentContent.sections
    }

    var showsNoMatchesState: Bool {
        currentContent.showsNoMatchesState
    }

    func performPrimaryAction(for item: InventoryItem) {
        selectedItemID = item.id
        guard let action = item.primaryAction else { return }
        actionHandler.perform(action, on: item)
    }

    func perform(_ action: InventoryAction, on item: InventoryItem) {
        selectedItemID = item.id
        actionHandler.perform(action, on: item)
    }

    private func observeStore() {
        withObservationTracking {
            _ = skillsStore.skills
            _ = skillsStore.mcpServers
            _ = skillsStore.agents
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeStore()
                self?.rebuild()
            }
        }
    }

    private func rebuild() {
        currentContent = InventorySectionsBuilder.buildContent(
            for: selectedTab,
            snapshot: InventorySnapshot(
                skills: skillsStore.skills,
                mcpServers: skillsStore.mcpServers,
                agents: skillsStore.agents
            ),
            filterText: filterText
        )
    }
}
