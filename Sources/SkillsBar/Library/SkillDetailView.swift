import SkillsBarCore
import SwiftUI

struct SkillDetailView: View {
    let item: InventoryItem
    let skill: Skill
    let actionHandler: InventoryActionHandler

    @State private var showingInfo = false

    var body: some View {
        InventoryDetailScrollView {
            InventoryDetailHeroView(
                item: item,
                statusText: item.isEnabled ? "Enabled" : "Disabled",
                trailingInfo: skill.agent.displayName
            )

            InventoryDetailSectionView(title: "Actions") {
                InventoryActionButtonsView(item: item, actionHandler: actionHandler, showingInfo: $showingInfo)
                if showingInfo, let infoMessage = item.infoMessage {
                    InventoryInfoCalloutView(message: infoMessage)
                }
            }

            InventoryDetailSectionView(title: "Overview") {
                InventoryDetailField(label: "Agent", value: skill.agent.displayName, multiline: false)
                InventoryDetailField(label: "Source", value: skill.source.displayName, multiline: false)
                if let pluginName = skill.pluginName {
                    InventoryDetailField(label: "Plugin", value: pluginName, multiline: false)
                }
                if let repo = skill.marketplaceRepo {
                    InventoryDetailField(label: "Marketplace", value: repo, multiline: false)
                } else if let marketplaceName = skill.marketplaceName {
                    InventoryDetailField(label: "Marketplace", value: marketplaceName, multiline: false)
                }
                InventoryDetailField(label: "User Invocable", value: item.isUserInvocable == false ? "No" : "Yes", multiline: false)
                InventoryDetailField(label: "Toggle Capability", value: skill.toggleCapability.rawValue.capitalized, multiline: false)
            }

            InventoryDetailSectionView(title: "Locations") {
                InventoryDetailField(label: "Active Location", value: skill.path.path, monospaced: true)
                InventoryDetailField(label: "Skill File", value: skill.skillFilePath.path, monospaced: true)
                if let canonicalPath = skill.canonicalPath {
                    InventoryDetailField(label: "Canonical Path", value: canonicalPath.path, monospaced: true)
                }
                if let projectRoot = skill.projectRoot {
                    InventoryDetailField(label: "Project Root", value: projectRoot.path, monospaced: true)
                }
            }

            if let metadata = skill.metadata {
                InventoryDetailSectionView(title: "Metadata") {
                    if let author = metadata.author {
                        InventoryDetailField(label: "Author", value: author, multiline: false)
                    }
                    if let version = metadata.version {
                        InventoryDetailField(label: "Version", value: version, multiline: false)
                    }
                    if let compatibility = metadata.compatibility {
                        InventoryDetailField(label: "Compatibility", value: compatibility)
                    }
                    InventoryDetailField(
                        label: "Model Invocation",
                        value: metadata.disableModelInvocation ? "Disabled" : "Enabled",
                        multiline: false
                    )
                    InventoryDetailField(
                        label: "User Invocation",
                        value: metadata.userInvocable ? "Enabled" : "Disabled",
                        multiline: false
                    )
                    if let allowedTools = metadata.allowedTools, !allowedTools.isEmpty {
                        InventoryDetailField(label: "Allowed Tools", value: allowedTools.joined(separator: ", "))
                    }
                }
            }
        }
    }
}
