import AppKit
import SkillsBarCore
import SwiftUI

enum PreferencesTab: String, Hashable {
    case general
    case agents
    case sources
    case about
}

@MainActor
struct PreferencesView: View {
    @Bindable var settings: SettingsStore
    @Bindable var skillsStore: SkillsStore
    let updater: UpdaterProviding

    @State private var selectedTab: PreferencesTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralPane(settings: settings, updater: updater)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(PreferencesTab.general)

            AgentsPane(settings: settings)
                .tabItem { Label("Agents", systemImage: "cpu") }
                .tag(PreferencesTab.agents)

            SourcesPane(settings: settings, skillsStore: skillsStore)
                .tabItem { Label("Sources", systemImage: "folder") }
                .tag(PreferencesTab.sources)

            AboutPane(updater: updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(PreferencesTab.about)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(width: 480, height: 420)
    }
}

// MARK: - General Pane

struct GeneralPane: View {
    @Bindable var settings: SettingsStore
    let updater: UpdaterProviding

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            } header: {
                Text("Startup")
            }

            Section {
                if updater.isAvailable {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))

                    Button("Check for Updates Now") {
                        updater.checkForUpdates(nil)
                    }
                } else {
                    if let reason = updater.unavailableReason {
                        Text(reason)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Updates not available")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Updates")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Sources Pane

struct SourcesPane: View {
    @Bindable var settings: SettingsStore
    @Bindable var skillsStore: SkillsStore

    /// Combined view of all folder paths with their recursive state
    private var allFolders: [(url: URL, isRecursive: Bool)] {
        let direct = settings.projectPaths.map { (url: $0, isRecursive: false) }
        let recursive = settings.recursiveProjectPaths.map { (url: $0, isRecursive: true) }
        return (direct + recursive).sorted { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Global skills", isOn: $settings.showGlobalSkills)
                Toggle("Plugin skills", isOn: $settings.showPluginSkills)
                Toggle("Project skills", isOn: $settings.showProjectSkills)
            } header: {
                Text("Skill Sources")
            }

            Section {
                Toggle("Global MCPs", isOn: $settings.showGlobalMCPs)
                Toggle("Project MCPs", isOn: $settings.showProjectMCPs)
                Toggle("Built-in MCPs", isOn: $settings.showBuiltInMCPs)
            } header: {
                Text("MCP Sources")
            }

            Section {
                if allFolders.isEmpty {
                    Text("No folders added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allFolders, id: \.url.path) { folder in
                        FolderRow(
                            url: folder.url,
                            isRecursive: folder.isRecursive,
                            coveredBy: folder.isRecursive ? nil : RecursivePathExpander.coveredByRecursive(folder.url, in: settings.recursiveProjectPaths),
                            onToggleRecursive: { toggleRecursive(folder.url, currentlyRecursive: folder.isRecursive) },
                            onRemove: { removeFolder(folder.url, isRecursive: folder.isRecursive) }
                        )
                    }
                }
                HStack {
                    Spacer()
                    Button("Add Folder...") {
                        selectFolder()
                    }
                    if !allFolders.isEmpty {
                        Button("Clear All") {
                            settings.projectPaths = []
                            settings.recursiveProjectPaths = []
                            skillsStore.clearProjectPaths()
                            skillsStore.clearRecursiveProjectPaths()
                        }
                    }
                }
            } header: {
                Text("Folders")
            }

        }
        .formStyle(.grouped)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select folders to discover skills from"

        if panel.runModal() == .OK {
            for url in panel.urls {
                let alreadyExists = settings.projectPaths.contains(url) || settings.recursiveProjectPaths.contains(url)
                if !alreadyExists {
                    settings.projectPaths.append(url)
                    skillsStore.addProjectPath(url)
                }
            }
        }
    }

    private func toggleRecursive(_ url: URL, currentlyRecursive: Bool) {
        if currentlyRecursive {
            // Move from recursive to direct
            settings.recursiveProjectPaths.removeAll { $0 == url }
            skillsStore.removeRecursiveProjectPath(url)
            settings.projectPaths.append(url)
            skillsStore.addProjectPath(url)
        } else {
            // Move from direct to recursive
            settings.projectPaths.removeAll { $0 == url }
            skillsStore.removeProjectPath(url)
            settings.recursiveProjectPaths.append(url)
            skillsStore.addRecursiveProjectPath(url)
        }
    }

    private func removeFolder(_ url: URL, isRecursive: Bool) {
        if isRecursive {
            settings.recursiveProjectPaths.removeAll { $0 == url }
            skillsStore.removeRecursiveProjectPath(url)
        } else {
            settings.projectPaths.removeAll { $0 == url }
            skillsStore.removeProjectPath(url)
        }
    }
}

// MARK: - Folder Row

private struct FolderRow: View {
    let url: URL
    let isRecursive: Bool
    let coveredBy: URL?
    let onToggleRecursive: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false

    private var subfolderCount: Int {
        RecursivePathExpander.subfolderCount(for: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(url.lastPathComponent)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(isHovering ? .red : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .onHover { isHovering = $0 }

                Spacer()

                if coveredBy == nil {
                    Toggle(isOn: Binding(
                        get: { isRecursive },
                        set: { _ in onToggleRecursive() }
                    )) {
                        Text(isRecursive ? "Subfolders (\(subfolderCount))" : "Subfolders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
            }

            if let parent = coveredBy {
                Label("Already scanned by \(parent.lastPathComponent)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - About Pane

struct AboutPane: View {
    let updater: UpdaterProviding
    @State private var iconHover = false
    @AppStorage("autoUpdateEnabled") private var autoUpdateEnabled: Bool = true

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    var body: some View {
        VStack(spacing: 12) {
            if let image = NSApplication.shared.applicationIconImage {
                Button(action: openGitHub) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 92, height: 92)
                        .cornerRadius(16)
                        .scaleEffect(iconHover ? 1.05 : 1.0)
                        .shadow(color: iconHover ? .accentColor.opacity(0.25) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        iconHover = hovering
                    }
                }
            }

            VStack(spacing: 2) {
                Text("SkillsBar")
                    .font(.title3).bold()

                Text("Version \(versionString)")
                    .foregroundStyle(.secondary)

                Text("Know your skills and MCPs before your agent does.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .center, spacing: 10) {
                AboutLinkRow(
                    icon: "chevron.left.slash.chevron.right",
                    title: "GitHub",
                    url: "https://github.com/alberduris/SkillsBar")
                AboutLinkRow(
                    icon: "bird",
                    title: "Twitter",
                    url: "https://twitter.com/alberduris")
                AboutLinkRow(
                    icon: "envelope",
                    title: "Email",
                    url: "mailto:alberduris@summiz.ai")
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            Divider()

            if updater.isAvailable {
                VStack(spacing: 10) {
                    Toggle("Check for updates automatically", isOn: $autoUpdateEnabled)
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button("Check for Updates…") {
                        updater.checkForUpdates(nil)
                    }
                }
                .onChange(of: autoUpdateEnabled) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }
            } else {
                Text(updater.unavailableReason ?? "Updates unavailable in this build.")
                    .foregroundStyle(.secondary)
            }

            Text("© 2026 Alber 🍑/acc. MIT License.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func openGitHub() {
        if let url = URL(string: "https://github.com/alberduris/SkillsBar") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - About Link Row

private struct AboutLinkRow: View {
    let icon: String
    let title: String
    let url: String

    @State private var isHovering = false

    var body: some View {
        Button(action: openURL) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
            }
            .foregroundStyle(isHovering ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}
