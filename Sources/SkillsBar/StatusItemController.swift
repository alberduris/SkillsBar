import AppKit
import SkillsBarCore
import SwiftUI

/// Controls the menu bar status item for SkillsBar
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private static let menuCardBaseWidth: CGFloat = 420

    private let statusItem: NSStatusItem
    private let skillsStore: SkillsStore
    private let settings: SettingsStore
    private let updater: UpdaterProviding
    private let popover = NSPopover()
    private var hostingController: NSHostingController<SkillsMenuCardView>?

    init(skillsStore: SkillsStore, settings: SettingsStore, updater: UpdaterProviding) {
        self.skillsStore = skillsStore
        self.settings = settings
        self.updater = updater
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        setupStatusItem()
        configurePopover()
        observeChanges()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        // Render at 1:1 without resampling for crisp template images
        button.imageScaling = .scaleNone
        updateIcon()

        button.target = self
        button.action = #selector(togglePopover)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
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

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        rebuildPopoverContent()
        updatePopoverSize()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        Task {
            await skillsStore.refresh()
        }
    }

    private func rebuildPopoverContent() {
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
        let controller = NSHostingController(rootView: cardView)
        hostingController = controller
        popover.contentViewController = controller
    }

    private func updatePopoverSize() {
        guard let view = hostingController?.view else { return }
        view.layoutSubtreeIfNeeded()
        let fittingSize = view.fittingSize
        popover.contentSize = NSSize(width: Self.menuCardBaseWidth, height: fittingSize.height)
    }

    // MARK: - Actions

    private func openSettings() {
        popover.performClose(nil)
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
