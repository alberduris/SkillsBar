import SkillsBarCore
import SwiftUI

struct MCPDetailView: View {
    let item: InventoryItem
    let server: MCPServer
    let actionHandler: InventoryActionHandler

    @State private var showingInfo = false

    var body: some View {
        InventoryDetailScrollView {
            InventoryDetailHeroView(
                item: item,
                statusText: item.isEnabled ? "Enabled" : "Disabled",
                trailingInfo: server.transport.description
            )

            InventoryDetailSectionView(title: "Actions") {
                InventoryActionButtonsView(item: item, actionHandler: actionHandler, showingInfo: $showingInfo)
            }

            InventoryDetailSectionView(title: "Overview") {
                InventoryDetailField(label: "Transport", value: server.transport.description, multiline: false)
                InventoryDetailField(label: "Source", value: server.source.displayName, multiline: false)
                if let projectName = server.projectName {
                    InventoryDetailField(label: "Project", value: projectName, multiline: false)
                }
                if let pluginName = server.pluginName {
                    InventoryDetailField(label: "Plugin", value: pluginName, multiline: false)
                }
                if let marketplaceRepo = server.marketplaceRepo {
                    InventoryDetailField(label: "Marketplace", value: marketplaceRepo, multiline: false)
                }
            }

            InventoryDetailSectionView(title: "Connection") {
                if let url = server.url {
                    InventoryDetailField(label: "URL", value: url, monospaced: true)
                }
                if let command = server.command {
                    InventoryDetailField(label: "Command", value: command, monospaced: true, multiline: false)
                }
                if !server.args.isEmpty {
                    InventoryDetailField(label: "Arguments", value: server.args.joined(separator: " "), monospaced: true)
                }
            }

            if !server.envKeys.isEmpty || !server.headerKeys.isEmpty {
                InventoryDetailSectionView(title: "Secrets & Headers") {
                    if !server.envKeys.isEmpty {
                        InventoryDetailField(label: "Env Keys", value: server.envKeys.joined(separator: ", "))
                    }
                    if !server.headerKeys.isEmpty {
                        InventoryDetailField(label: "Header Keys", value: server.headerKeys.joined(separator: ", "))
                    }
                }
            }
        }
    }
}
