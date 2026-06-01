import SwiftUI

/// User-facing accent themes applied across the island UI.
enum AccentTheme: String, CaseIterable, Identifiable {
    case teal, blue, purple, pink, orange, green, graphite

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal: return .teal
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .orange: return .orange
        case .green: return .green
        case .graphite: return Color(white: 0.7)
        }
    }

    var label: String { rawValue.capitalized }
}

/// Central, persisted user preferences. Injected into the SwiftUI environment
/// and referenced by the view model for behavior gating.
@MainActor
final class SettingsStore: ObservableObject {
    // MARK: General
    @Published var launchAtLogin: Bool { didSet { persist(launchAtLogin, "launchAtLogin") } }

    // MARK: Behavior
    @Published var expandOnHover: Bool { didSet { persist(expandOnHover, "expandOnHover") } }
    /// Extra padding (px) around the notch that triggers the hover open.
    @Published var hoverTriggerSize: Double { didSet { persist(hoverTriggerSize, "hoverTriggerSize") } }
    /// Seconds the pointer can be away before the island collapses.
    @Published var autoCollapseDelay: Double { didSet { persist(autoCollapseDelay, "autoCollapseDelay") } }

    // MARK: Appearance
    @Published var accent: AccentTheme { didSet { persist(accent.rawValue, "accent") } }
    /// When true, `customAccent` overrides the preset `accent`.
    @Published var useCustomAccent: Bool { didSet { persist(useCustomAccent, "useCustomAccent") } }
    /// User-chosen accent from the color wheel (persisted as RGBA components).
    @Published var customAccent: Color {
        didSet {
            let c = NSColor(customAccent).usingColorSpace(.sRGB) ?? .systemTeal
            persist([Double(c.redComponent), Double(c.greenComponent),
                     Double(c.blueComponent), Double(c.alphaComponent)], "customAccentRGBA")
        }
    }
    /// The effective accent color used across the UI.
    var accentColor: Color { useCustomAccent ? customAccent : accent.color }
    /// Show artwork + bars in the collapsed notch while music plays.
    @Published var showCompactMedia: Bool { didSet { persist(showCompactMedia, "showCompactMedia") } }
    /// Keep the compact player in the notch when playback is paused/stopped.
    @Published var keepPlayerWhilePaused: Bool { didSet { persist(keepPlayerWhilePaused, "keepPlayerWhilePaused") } }
    /// Show the animated equalizer bars.
    @Published var showEqualizer: Bool { didSet { persist(showEqualizer, "showEqualizer") } }

    // MARK: Features / tabs (Media is always available)
    @Published var showCalendarTab: Bool { didSet { persist(showCalendarTab, "showCalendarTab") } }
    @Published var showMirrorTab: Bool { didSet { persist(showMirrorTab, "showMirrorTab") } }
    @Published var showShelfTab: Bool { didSet { persist(showShelfTab, "showShelfTab") } }
    @Published var showNotesTab: Bool { didSet { persist(showNotesTab, "showNotesTab") } }

    // MARK: Clipboard
    @Published var clipboardEnabled: Bool { didSet { persist(clipboardEnabled, "clipboardEnabled") } }
    @Published var clipboardMaxItems: Int { didSet { persist(clipboardMaxItems, "clipboardMaxItems") } }
    @Published var clipboardRetention: ClipboardRetention {
        didSet { persist(clipboardRetention.rawValue, "clipboardRetentionSeconds") }
    }

    // MARK: Mirror
    @Published var mirrorFlip: Bool { didSet { persist(mirrorFlip, "mirrorFlip") } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? false
        expandOnHover = defaults.object(forKey: "expandOnHover") as? Bool ?? true
        hoverTriggerSize = defaults.object(forKey: "hoverTriggerSize") as? Double ?? 12
        autoCollapseDelay = defaults.object(forKey: "autoCollapseDelay") as? Double ?? 0.16
        accent = AccentTheme(rawValue: defaults.string(forKey: "accent") ?? "") ?? .teal
        useCustomAccent = defaults.object(forKey: "useCustomAccent") as? Bool ?? false
        if let rgba = defaults.array(forKey: "customAccentRGBA") as? [Double], rgba.count == 4 {
            customAccent = Color(.sRGB, red: rgba[0], green: rgba[1], blue: rgba[2], opacity: rgba[3])
        } else {
            customAccent = .teal
        }
        showCompactMedia = defaults.object(forKey: "showCompactMedia") as? Bool ?? true
        keepPlayerWhilePaused = defaults.object(forKey: "keepPlayerWhilePaused") as? Bool ?? true
        showEqualizer = defaults.object(forKey: "showEqualizer") as? Bool ?? true
        showCalendarTab = defaults.object(forKey: "showCalendarTab") as? Bool ?? true
        showMirrorTab = defaults.object(forKey: "showMirrorTab") as? Bool ?? true
        showShelfTab = defaults.object(forKey: "showShelfTab") as? Bool ?? true
        showNotesTab = defaults.object(forKey: "showNotesTab") as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: "clipboardEnabled") as? Bool ?? true
        clipboardMaxItems = defaults.object(forKey: "clipboardMaxItems") as? Int ?? 15
        let storedRetention = defaults.integer(forKey: "clipboardRetentionSeconds")
        clipboardRetention = ClipboardRetention(rawValue: storedRetention) ?? .oneHour
        mirrorFlip = defaults.object(forKey: "mirrorFlip") as? Bool ?? true
    }

    /// Which tabs sit to the left of the notch, in order.
    func leftTabs() -> [IslandMode] {
        var tabs: [IslandMode] = [.media]
        if showCalendarTab { tabs.append(.calendar) }
        if showMirrorTab { tabs.append(.mirror) }
        return tabs
    }

    /// Which tabs sit to the right of the notch, in order.
    func rightTabs() -> [IslandMode] {
        var tabs: [IslandMode] = []
        if showShelfTab { tabs.append(.shelf) }
        if showNotesTab { tabs.append(.notes) }
        if clipboardEnabled { tabs.append(.clipboard) }
        return tabs
    }

    func isTabEnabled(_ mode: IslandMode) -> Bool {
        switch mode {
        case .media: return true
        case .calendar: return showCalendarTab
        case .mirror: return showMirrorTab
        case .shelf: return showShelfTab
        case .notes: return showNotesTab
        case .clipboard: return clipboardEnabled
        }
    }

    func resetToDefaults() {
        launchAtLogin = false
        expandOnHover = true
        hoverTriggerSize = 12
        autoCollapseDelay = 0.16
        accent = .teal
        useCustomAccent = false
        customAccent = .teal
        showCompactMedia = true
        keepPlayerWhilePaused = true
        showEqualizer = true
        showCalendarTab = true
        showMirrorTab = true
        showShelfTab = true
        showNotesTab = true
        clipboardEnabled = true
        clipboardMaxItems = 15
        clipboardRetention = .oneHour
        mirrorFlip = true
    }

    private func persist(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
