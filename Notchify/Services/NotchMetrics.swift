import AppKit

enum NotchMetrics {
    static let maxPanelSize = CGSize(width: 760, height: 320)

    static func closedNotchSize(on screen: NSScreen?) -> CGSize {
        guard let screen else { return CGSize(width: 210, height: 34) }

        var width: CGFloat = 210
        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let computed = screen.frame.width - left.width - right.width + 4
            if computed.isFinite, computed > 120 {
                width = computed
            }
        }

        let safeTop = screen.safeAreaInsets.top
        let menuHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        let rawHeight = safeTop > 0 ? safeTop : max(30, min(menuHeight, 36))
        // Round to whole pixels so the idle player's bottom edge lands exactly
        // on the notch edge instead of a blurry sub-pixel offset (the 2-3px gap).
        let height = (max(28, min(rawHeight, 42))).rounded()
        return CGSize(width: max(170, min(width, 260)).rounded(), height: height)
    }

    static func triggerRect(on screen: NSScreen, padding: CGFloat = 12) -> NSRect {
        let notch = closedNotchSize(on: screen)
        let horizontal = padding * 2
        let vertical = padding
        return NSRect(
            x: screen.frame.midX - (notch.width + horizontal) / 2,
            y: screen.frame.maxY - (notch.height + vertical),
            width: notch.width + horizontal,
            height: notch.height + vertical
        )
    }
}
