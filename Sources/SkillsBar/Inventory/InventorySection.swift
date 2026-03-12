import Foundation
import SkillsBarCore

struct InventorySection: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let items: [InventoryItem]
    let trailingText: String?
    let note: String?
}

struct InventoryTabContent: Hashable {
    let sections: [InventorySection]
    let showsNoMatchesState: Bool

    static let empty = InventoryTabContent(sections: [], showsNoMatchesState: false)
}

struct InventorySnapshot: Hashable {
    let skills: [Skill]
    let mcpServers: [MCPServer]
    let agents: [AgentProfile]
}
