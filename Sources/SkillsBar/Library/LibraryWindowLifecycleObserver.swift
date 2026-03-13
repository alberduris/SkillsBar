import AppKit
import SwiftUI

struct LibraryWindowLifecycleObserver: NSViewRepresentable {
    let onWindowOpen: () -> Void
    let onWindowClose: () -> Void

    func makeCoordinator() -> LibraryWindowLifecycleCoordinator {
        LibraryWindowLifecycleCoordinator(onWindowOpen: onWindowOpen, onWindowClose: onWindowClose)
    }

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserverNSView()
        view.onWindowChange = { window in
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observerView = nsView as? WindowObserverNSView {
            observerView.onWindowChange = { window in
                context.coordinator.attach(to: window)
            }
        }
    }
}

final class LibraryWindowLifecycleCoordinator {
    private let onWindowOpen: () -> Void
    private let onWindowClose: () -> Void
    private weak var observedWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?

    init(onWindowOpen: @escaping () -> Void, onWindowClose: @escaping () -> Void) {
        self.onWindowOpen = onWindowOpen
        self.onWindowClose = onWindowClose
    }

    deinit {
        detachObserver()
    }

    func attach(to window: NSWindow?) {
        guard let window else { return }
        guard observedWindow !== window else { return }

        detachObserver()
        observedWindow = window
        onWindowOpen()

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.onWindowClose()
            self?.detachObserver()
        }
    }

    private func detachObserver() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
        closeObserver = nil
        observedWindow = nil
    }
}

private final class WindowObserverNSView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
