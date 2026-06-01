import SwiftUI

/// Centralized animation curves so every part of the island moves with one
/// cohesive, fluid feel. These use SwiftUI's modern fluid spring presets
/// (macOS 14+), which are fully interruptible - key to smoothness when the
/// user hovers in and out quickly.
extension Animation {
    /// Island opening, closing, and resizing. A smooth spring with just a
    /// touch of life so the resize feels organic but never wobbly.
    static let islandResize = Animation.smooth(duration: 0.46, extraBounce: 0.14)

    /// Switching tabs / swapping the expanded content.
    static let islandContent = Animation.smooth(duration: 0.36, extraBounce: 0.06)

    /// Small UI micro-interactions (tab highlight, note open/close, buttons).
    static let islandSnappy = Animation.snappy(duration: 0.28, extraBounce: 0.04)

    /// The compact now-playing transition and other quick fades.
    static let islandQuick = Animation.smooth(duration: 0.3)
}
