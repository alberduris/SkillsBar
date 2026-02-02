import SkillsBarCore
import SwiftUI

/// A hidden window view that enables opening Settings from non-SwiftUI code.
/// This is necessary because @Environment(\.openSettings) is only available in SwiftUI Views.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onReceive(NotificationCenter.default.publisher(for: .skillsbarOpenSettings)) { _ in
                SkillsBarLog.logger(LogCategories.app).info("HiddenWindowView received openSettings notification")
                Task { @MainActor in
                    self.openSettings()
                }
            }
            .onAppear {
                SkillsBarLog.logger(LogCategories.app).info("HiddenWindowView appeared")
                if let window = NSApp.windows.first(where: { $0.title == "SkillsBarLifecycleKeepalive" }) {
                    SkillsBarLog.logger(LogCategories.app).info("Found lifecycle window, hiding it")
                    // Make the keepalive window truly invisible and non-interactive.
                    window.styleMask = [.borderless]
                    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                    window.isExcludedFromWindowsMenu = true
                    window.level = .floating
                    window.isOpaque = false
                    window.alphaValue = 0
                    window.backgroundColor = .clear
                    window.hasShadow = false
                    window.ignoresMouseEvents = true
                    window.canHide = false
                    window.setContentSize(NSSize(width: 1, height: 1))
                    window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                } else {
                    SkillsBarLog.logger(LogCategories.app).warning("Lifecycle window not found!")
                }
            }
    }
}
