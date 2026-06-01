import AppKit
import SwiftUI

@MainActor
final class OverlayPanel: NSPanel {
    init<Content: View>(rootView: Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 310),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        worksWhenModal = true
        ignoresMouseEvents = true
        animationBehavior = .none
        isMovable = false
        // Only take keyboard focus when a control that needs it (e.g. the notes
        // text editor) is clicked. Clicking a tab/button then won't steal focus
        // from whatever app the user was typing in.
        becomesKeyOnlyIfNeeded = true

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
        orderFrontRegardless()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

