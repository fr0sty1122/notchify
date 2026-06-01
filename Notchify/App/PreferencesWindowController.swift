import AppKit
import SwiftUI

/// Owns a standalone preferences window hosting the SwiftUI settings UI.
///
/// We deliberately avoid SwiftUI's `Settings` scene: in an `.accessory`
/// (LSUIElement) app it frequently fails to present a usable window, which is
/// why the panel showed in the Dock but never opened. Managing our own
/// `NSWindow` is reliable and gives full control over activation.
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: IslandViewModel

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func show() {
        // Become a regular app while preferences are open so the window can
        // become key and accept input, and so it gets a normal title bar.
        NSApp.setActivationPolicy(.regular)

        if window == nil {
            let hosting = NSHostingController(rootView: PreferencesView(viewModel: viewModel))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Notchify Settings"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            window = win
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        // Center after ordering front so the window has its final size and the
        // screen geometry is fully resolved — avoids the top-right drift.
        centerOnScreen()
    }

    private func centerOnScreen() {
        guard let win = window,
              let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let sf = screen.visibleFrame
        let wf = win.frame
        let x = sf.midX - wf.width / 2
        let y = sf.midY - wf.height / 2
        win.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    // Drop back to accessory (no Dock icon) once preferences close.
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
