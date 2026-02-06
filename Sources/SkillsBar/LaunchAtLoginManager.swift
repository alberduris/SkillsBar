import Foundation
import SkillsBarCore
import ServiceManagement

enum LaunchAtLoginManager {
    private static let isRunningTests: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["TESTING_LIBRARY_VERSION"] != nil { return true }
        if env["SWIFT_TESTING"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }()

    /// Launch-at-login registration only works reliably when running from a real app bundle.
    /// If we run the debug executable directly from `.build/.../debug/SkillsBar`, registration
    /// can create duplicate login items that open Terminal at startup.
    private static var canManageLaunchAtLogin: Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app", Bundle.main.bundleIdentifier != nil else {
            return false
        }

        guard let executablePath = CommandLine.arguments.first, !executablePath.isEmpty else {
            return false
        }

        let executableURL = URL(fileURLWithPath: executablePath).standardizedFileURL
        let bundleExecutableDir = bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .standardizedFileURL

        return executableURL.path.hasPrefix(bundleExecutableDir.path + "/")
    }

    /// Called when the user explicitly toggles the setting.
    static func setEnabled(_ enabled: Bool) {
        if self.isRunningTests { return }
        guard canManageLaunchAtLogin else { return }
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            SkillsBarLog.logger(LogCategories.launchAtLogin).error("Failed to update login item: \(error)")
        }
    }

    /// Called on app launch to reconcile state without creating duplicates.
    /// Only acts if the persisted preference disagrees with the actual registration status.
    static func syncIfNeeded(_ enabled: Bool) {
        if self.isRunningTests { return }
        guard canManageLaunchAtLogin else { return }
        let service = SMAppService.mainApp
        let isRegistered = service.status == .enabled
        guard enabled != isRegistered else { return }
        setEnabled(enabled)
    }
}
