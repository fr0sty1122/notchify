import AppKit

@MainActor
final class WindowPositioningService {
    private weak var panel: NSPanel?
    private var observers: [NSObjectProtocol] = []

    init(panel: NSPanel) {
        self.panel = panel
        observeDisplayChanges()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reposition(for size: CGSize) {
        guard let screen = targetScreen(), let panel else { return }
        let frame = screen.frame
        let targetFrame = NSRect(
            x: (frame.midX - size.width / 2).rounded(),
            y: (frame.maxY - size.height).rounded(),
            width: size.width,
            height: size.height
        )
        panel.setFrame(targetFrame, display: true, animate: false)
    }

    private func targetScreen() -> NSScreen? {
        if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) {
            return mouseScreen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func observeDisplayChanges() {
        observers = [NSApplication.didChangeScreenParametersNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let panel = self.panel else { return }
                    self.reposition(for: panel.frame.size)
                }
            }
        }
    }
}

