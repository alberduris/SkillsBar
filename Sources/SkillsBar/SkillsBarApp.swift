import AppKit
import Observation
import SkillsBarCore
import SwiftUI

@main
struct SkillsBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var skillsStore: SkillsStore
    @State private var settings: SettingsStore

    init() {
        // Bootstrap logging
        let env = ProcessInfo.processInfo.environment
        let storedLevel = SkillsBarLog.parseLevel(UserDefaults.standard.string(forKey: "debugLogLevel")) ?? .info
        let level = SkillsBarLog.parseLevel(env["SKILLSBAR_LOG_LEVEL"]) ?? storedLevel
        SkillsBarLog.bootstrapIfNeeded(.init(
            destination: .oslog(subsystem: "com.skillsbar.app"),
            level: level,
            json: false))

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        SkillsBarLog.logger(LogCategories.app).info(
            "SkillsBar starting",
            metadata: [
                "version": "\(version)",
                "build": "\(build)",
            ])

        let settings = SettingsStore()
        let skillsStore = SkillsStore.shared

        // Sync project paths from persisted settings to skills store
        skillsStore.projectPaths = settings.projectPaths
        skillsStore.recursiveProjectPaths = settings.recursiveProjectPaths

        _settings = State(wrappedValue: settings)
        _skillsStore = State(wrappedValue: skillsStore)

        appDelegate.configure(skillsStore: skillsStore, settings: settings)
    }

    var body: some Scene {
        WindowGroup("SkillsBarLifecycleKeepalive") {
            HiddenWindowView()
        }
        .defaultSize(width: 20, height: 20)
        .windowStyle(.hiddenTitleBar)

        Settings {
            PreferencesView(settings: settings, skillsStore: skillsStore, updater: appDelegate.updaterController)
        }
        .defaultSize(width: 500, height: 400)
        .windowResizability(.contentSize)
    }
}

// MARK: - Updater abstraction

@MainActor
protocol UpdaterProviding: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var isAvailable: Bool { get }
    var unavailableReason: String? { get }
    var updateStatus: UpdateStatus { get }
    func checkForUpdates(_ sender: Any?)
}

/// No-op updater used for debug builds and non-bundled runs
final class DisabledUpdaterController: UpdaterProviding {
    var automaticallyChecksForUpdates: Bool = false
    var automaticallyDownloadsUpdates: Bool = false
    let isAvailable: Bool = false
    let unavailableReason: String?
    let updateStatus = UpdateStatus()

    init(unavailableReason: String? = nil) {
        self.unavailableReason = unavailableReason
    }

    func checkForUpdates(_ sender: Any?) {}
}

@MainActor
@Observable
final class UpdateStatus {
    static let disabled = UpdateStatus()
    var isUpdateReady: Bool

    init(isUpdateReady: Bool = false) {
        self.isUpdateReady = isUpdateReady
    }
}

@MainActor
private func makeUpdaterController() -> UpdaterProviding {
    DisabledUpdaterController()
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    let updaterController: UpdaterProviding = makeUpdaterController()
    private var statusController: StatusItemController?
    private var skillsStore: SkillsStore?
    private var settings: SettingsStore?

    func configure(skillsStore: SkillsStore, settings: SettingsStore) {
        self.skillsStore = skillsStore
        self.settings = settings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        // Menu bar only app (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        ensureStatusController()

        // Initial refresh
        Task {
            await skillsStore?.refresh()
        }
    }

    private func ensureStatusController() {
        if statusController != nil { return }

        guard let skillsStore, let settings else {
            SkillsBarLog.logger(LogCategories.app)
                .error("StatusItemController creation failed; stores not configured.")
            return
        }

        statusController = StatusItemController(
            skillsStore: skillsStore,
            settings: settings,
            updater: updaterController
        )
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .skillsbarOpenSettings, object: nil)
    }
}
