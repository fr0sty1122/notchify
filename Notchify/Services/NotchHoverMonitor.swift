import AppKit

@MainActor
final class NotchHoverMonitor {
    private weak var panel: NSPanel?
    private let islandFrameProvider: () -> NSRect
    private let onHoverChange: (Bool) -> Void
    private let onScreenChange: (NSScreen?) -> Void
    /// Extra padding (px) around the notch that counts as the hover trigger.
    var triggerPaddingProvider: () -> CGFloat = { 12 }
    /// Grace period (seconds) before collapsing once the pointer leaves.
    var collapseDelayProvider: () -> TimeInterval = { 0.16 }
    private var timer: Timer?
    private var isHovering = false
    private var pendingCollapseAt: Date?
    private var lastScreen: NSScreen?
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    init(
        panel: NSPanel,
        islandFrameProvider: @escaping () -> NSRect,
        onHoverChange: @escaping (Bool) -> Void,
        onScreenChange: @escaping (NSScreen?) -> Void
    ) {
        self.panel = panel
        self.islandFrameProvider = islandFrameProvider
        self.onHoverChange = onHoverChange
        self.onScreenChange = onScreenChange
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        installMouseMonitors()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        globalMouseMonitor = nil
        localMouseMonitor = nil
    }

    private func tick() {
        guard let screen = activeScreen() else { return }
        if screen != lastScreen {
            lastScreen = screen
            onScreenChange(screen)
        }

        let mouse = NSEvent.mouseLocation
        let insideTrigger = NotchMetrics.triggerRect(on: screen, padding: triggerPaddingProvider()).contains(mouse)
        let insideIsland = isHovering && islandFrameProvider().insetBy(dx: -8, dy: -8).contains(mouse)
        if insideTrigger {
            pendingCollapseAt = nil
            setHovering(true)
        } else if isHovering && insideIsland {
            pendingCollapseAt = nil
        } else if isHovering {
            if pendingCollapseAt == nil {
                pendingCollapseAt = Date().addingTimeInterval(collapseDelayProvider())
            }
            if let pendingCollapseAt, Date() >= pendingCollapseAt {
                self.pendingCollapseAt = nil
                setHovering(false)
            }
        }
    }

    private func installMouseMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closeIfClickOutside() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            Task { @MainActor in self?.closeIfClickOutside() }
            return event
        }
    }

    private func closeIfClickOutside() {
        guard isHovering else { return }
        let mouse = NSEvent.mouseLocation
        let retainedFrame = islandFrameProvider().insetBy(dx: -36, dy: -28)
        if !retainedFrame.contains(mouse) {
            setHovering(false)
        }
    }

    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        onHoverChange(hovering)
    }
}
