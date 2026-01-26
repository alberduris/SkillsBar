import AppKit
import SkillsBarCore
import SwiftUI

// MARK: - Vibrancy-enabled hosting view

@MainActor
private final class MenuCardItemHostingView<Content: View>: NSHostingView<Content> {
    override var allowsVibrancy: Bool { true }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        guard self.frame.width > 0 else { return size }
        return NSSize(width: self.frame.width, height: size.height)
    }
}

/// Controls the menu bar status item for SkillsBar
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let menuCardBaseWidth: CGFloat = 380

    private let statusItem: NSStatusItem
    private let skillsStore: SkillsStore
    private let settings: SettingsStore
    private let updater: UpdaterProviding
    private var menu: NSMenu?

    init(skillsStore: SkillsStore, settings: SettingsStore, updater: UpdaterProviding) {
        self.skillsStore = skillsStore
        self.settings = settings
        self.updater = updater
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupStatusItem()
        observeChanges()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        // Render at 1:1 without resampling for crisp template images
        button.imageScaling = .scaleNone
        updateIcon()

        // Create and attach menu
        let menu = NSMenu()
        menu.delegate = self
        self.menu = menu
        statusItem.menu = menu
    }

    private func observeChanges() {
        withObservationTracking {
            _ = skillsStore.skills
            _ = skillsStore.isRefreshing
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.observeChanges()
                self?.updateIcon()
            }
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let icon = IconRenderer.makeIcon(skillCount: skillsStore.totalCount)
        button.image = icon
    }

    // MARK: - NSMenuDelegate

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            self.rebuildMenu()
        }
    }

    nonisolated func menuWillOpen(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            self.rebuildMenu()
            // Refresh skills when menu opens
            Task {
                await self.skillsStore.refresh()
            }
        }
    }

    private func rebuildMenu() {
        guard let menu else { return }
        menu.removeAllItems()

        // Main card view
        let cardItem = NSMenuItem()
        let cardView = SkillsMenuCardView(
            skillsStore: skillsStore,
            onRefresh: { [weak self] in
                Task { await self?.skillsStore.refresh() }
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            },
            width: Self.menuCardBaseWidth
        )
        let hostingView = MenuCardItemHostingView(rootView: cardView)
        hostingView.frame.size = hostingView.fittingSize
        cardItem.view = hostingView
        menu.addItem(cardItem)
    }

    // MARK: - Actions

    private func openSettings() {
        menu?.cancelTracking()
        AppDelegate.shared?.openSettings()
    }
}

// MARK: - Icon Renderer

enum IconRenderer {
    /// Creates a skills icon for the menu bar
    static func makeIcon(skillCount: Int) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        guard let symbol = NSImage(systemSymbolName: "s.square.fill", accessibilityDescription: "SkillsBar")?
            .withSymbolConfiguration(config) else {
            return NSImage()
        }

        // Create image with standard menu bar height (22pt) and center the symbol
        let menuBarHeight: CGFloat = 22
        let symbolSize = symbol.size
        let finalSize = NSSize(width: symbolSize.width, height: menuBarHeight)

        let image = NSImage(size: finalSize, flipped: false) { rect in
            let y = (menuBarHeight - symbolSize.height) / 2
            symbol.draw(in: NSRect(x: 0, y: y, width: symbolSize.width, height: symbolSize.height))
            return true
        }
        image.isTemplate = true
        return image
    }
}
