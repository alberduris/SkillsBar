import SkillsBarCore
import SwiftUI

struct AgentDetailView: View {
    let item: InventoryItem
    let agent: AgentProfile
    let actionHandler: InventoryActionHandler

    @State private var showingInfo = false

    var body: some View {
        InventoryDetailScrollView {
            InventoryDetailHeroView(
                item: item,
                statusText: item.isEnabled ? "Enabled" : "Disabled",
                trailingInfo: agent.model
            )

            InventoryDetailSectionView(title: "Actions") {
                InventoryActionButtonsView(item: item, actionHandler: actionHandler, showingInfo: $showingInfo)
            }

            InventoryDetailSectionView(title: "Overview") {
                InventoryDetailField(label: "Source", value: agent.source.displayName, multiline: false)
                if let model = agent.model, !model.isEmpty {
                    InventoryDetailField(label: "Model", value: model, multiline: false)
                }
                if let pluginName = agent.pluginName {
                    InventoryDetailField(label: "Plugin", value: pluginName, multiline: false)
                }
                if let marketplaceRepo = agent.marketplaceRepo {
                    InventoryDetailField(label: "Marketplace", value: marketplaceRepo, multiline: false)
                } else if let marketplaceName = agent.marketplaceName {
                    InventoryDetailField(label: "Marketplace", value: marketplaceName, multiline: false)
                }
            }

            InventoryDetailSectionView(title: "Locations") {
                InventoryDetailField(label: "Agent File", value: agent.path.path, monospaced: true)
                if let projectRoot = agent.projectRoot {
                    InventoryDetailField(label: "Project Root", value: projectRoot.path, monospaced: true)
                }
            }
        }
    }
}
