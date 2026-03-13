import AppKit
import Foundation
import Observation
import SkillsBarCore

@MainActor @Observable
final class InventoryActionHandler {
    private let skillsStore: SkillsStore

    private(set) var togglingItemIDs: Set<String> = []

    init(skillsStore: SkillsStore) {
        self.skillsStore = skillsStore
    }

    func isToggling(_ itemID: String) -> Bool {
        togglingItemIDs.contains(itemID)
    }

    func perform(_ action: InventoryAction, on item: InventoryItem) {
        switch action {
        case .toggleEnabled:
            guard case let .skill(skill) = item.payload else { return }
            togglingItemIDs.insert(item.id)
            Task { @MainActor [weak self] in
                await self?.skillsStore.toggleSkill(skill)
                self?.togglingItemIDs.remove(item.id)
            }
        case .revealInFinder:
            guard let location = item.primaryLocation else { return }
            NSWorkspace.shared.activateFileViewerSelecting([location])
        case .openURL:
            guard let url = item.primaryURL else { return }
            NSWorkspace.shared.open(url)
        case .copyPath:
            guard let path = item.copyText else { return }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(path, forType: .string)
        case .showInfo:
            break
        }
    }
}
