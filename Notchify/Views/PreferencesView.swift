import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var settings: SettingsStore
    @State private var showResetConfirm = false

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        _settings = ObservedObject(wrappedValue: viewModel.settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                generalSection
                behaviorSection
                appearanceSection
                featuresSection
                clipboardSection
                aboutSection
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 480, height: 560)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notchify").font(.title2.bold())
                Text("Dynamic Island controls for your MacBook notch")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: General

    private var generalSection: some View {
        SettingsCard(title: "General", systemImage: "gearshape") {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Apple Events enables Apple Music and Spotify controls. Camera access enables the mirror.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    // MARK: Behavior

    private var behaviorSection: some View {
        SettingsCard(title: "Behavior", systemImage: "hand.tap") {
            Toggle("Expand when hovering the notch", isOn: $settings.expandOnHover)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hover trigger size")
                    Spacer()
                    Text("\(Int(settings.hoverTriggerSize)) px").foregroundStyle(.secondary)
                }
                Slider(value: $settings.hoverTriggerSize, in: 4...40, step: 1)
                    .disabled(!settings.expandOnHover)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Auto-collapse delay")
                    Spacer()
                    Text("\(settings.autoCollapseDelay, specifier: "%.2f") s").foregroundStyle(.secondary)
                }
                Slider(value: $settings.autoCollapseDelay, in: 0...1.5, step: 0.05)
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        SettingsCard(title: "Appearance", systemImage: "paintbrush") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Accent color").font(.subheadline.weight(.medium))
                HStack(spacing: 12) {
                    ForEach(AccentTheme.allCases) { theme in
                        let selected = !settings.useCustomAccent && settings.accent == theme
                        Circle()
                            .fill(theme.color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .opacity(selected ? 1 : 0)
                            )
                            .overlay(
                                Circle().stroke(.primary.opacity(0.6), lineWidth: selected ? 2 : 0)
                                    .padding(-3)
                            )
                            .onTapGesture {
                                settings.useCustomAccent = false
                                settings.accent = theme
                            }
                            .help(theme.label)
                    }
                    Spacer()
                }
                // Circular swatch (matching the presets) that opens the system
                // color panel; label + hex sit to its right.
                HStack(spacing: 10) {
                    AccentColorWell(color: $settings.customAccent, isActive: settings.useCustomAccent)
                        .frame(width: 26, height: 26)
                        .onChange(of: settings.customAccent) { _, _ in
                            settings.useCustomAccent = true
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Custom color").font(.callout)
                        Text(hexString(settings.customAccent))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            Divider()
            Toggle("Show compact player in the notch", isOn: $settings.showCompactMedia)
            Toggle("Keep compact player visible when paused", isOn: $settings.keepPlayerWhilePaused)
                .disabled(!settings.showCompactMedia)
            Toggle("Show equalizer", isOn: $settings.showEqualizer)
                .disabled(!settings.showCompactMedia)
        }
    }

    // MARK: Features

    private var featuresSection: some View {
        SettingsCard(title: "Tabs", systemImage: "square.grid.2x2") {
            HStack {
                Label("Media", systemImage: "music.note")
                Spacer()
                Text("Always on").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Toggle(isOn: $settings.showCalendarTab) { Label("Calendar", systemImage: "calendar") }
            Toggle(isOn: $settings.showMirrorTab) { Label("Mirror", systemImage: "person.crop.square") }
            Toggle(isOn: $settings.showShelfTab) { Label("Temporary Shelf", systemImage: "tray.full") }
            Toggle(isOn: $settings.showNotesTab) { Label("Quick Notes", systemImage: "note.text") }
            Toggle(isOn: $settings.mirrorFlip) {
                Label("Flip mirror preview", systemImage: "arrow.left.arrow.right")
            }
            .disabled(!settings.showMirrorTab)
        }
    }

    // MARK: Clipboard

    private var clipboardSection: some View {
        SettingsCard(title: "Clipboard", systemImage: "doc.on.clipboard") {
            Toggle("Enable clipboard history", isOn: $settings.clipboardEnabled)
            Divider()
            Picker("Keep items for", selection: $settings.clipboardRetention) {
                ForEach(ClipboardRetention.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .disabled(!settings.clipboardEnabled)
            Stepper(value: $settings.clipboardMaxItems, in: 5...50, step: 5) {
                Text("Max items: \(settings.clipboardMaxItems)")
            }
            .disabled(!settings.clipboardEnabled)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        SettingsCard(title: "About", systemImage: "info.circle") {
            HStack {
                Text("Version")
                Spacer()
                Text(version).foregroundStyle(.secondary)
            }
            Divider()
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset all settings", systemImage: "arrow.counterclockwise")
            }
            .confirmationDialog("Reset all settings to defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { settings.resetToDefaults() }
                Button("Cancel", role: .cancel) {}
            }
            Divider()
            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit Notchify", systemImage: "power")
            }
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    /// "#RRGGBB" string for a SwiftUI Color (sRGB).
    private func hexString(_ color: Color) -> String {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .black
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// A clean circular color swatch that opens the shared system color panel on
/// click and reports changes back. Drawing the circle ourselves avoids the
/// `NSColorWell` border chrome (which looked cropped when clipped).
private struct AccentColorWell: NSViewRepresentable {
    @Binding var color: Color
    var isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CircleColorView {
        let view = CircleColorView()
        view.onPick = { context.coordinator.parent.color = Color(nsColor: $0) }
        view.color = NSColor(color)
        view.showRing = isActive
        return view
    }

    func updateNSView(_ nsView: CircleColorView, context: Context) {
        nsView.color = NSColor(color)
        nsView.showRing = isActive
        nsView.needsDisplay = true
    }

    final class Coordinator: NSObject {
        let parent: AccentColorWell
        init(_ parent: AccentColorWell) { self.parent = parent }
    }

    final class CircleColorView: NSView, NSColorChanging {
        var color: NSColor = .systemTeal
        var showRing = false
        var onPick: ((NSColor) -> Void)?

        override var isFlipped: Bool { false }
        override var acceptsFirstResponder: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            let inset: CGFloat = showRing ? 3 : 0
            let rect = bounds.insetBy(dx: inset, dy: inset)
            let path = NSBezierPath(ovalIn: rect)
            color.setFill()
            path.fill()
            if showRing {
                NSColor.labelColor.withAlphaComponent(0.6).setStroke()
                let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
                ring.lineWidth = 2
                ring.stroke()
            }
        }

        override func mouseDown(with event: NSEvent) {
            let panel = NSColorPanel.shared
            panel.color = color
            panel.setTarget(self)
            panel.setAction(#selector(changeColor(_:)))
            panel.isContinuous = true
            panel.makeKeyAndOrderFront(nil)
        }

        @objc func changeColor(_ sender: NSColorPanel?) {
            guard let c = sender?.color else { return }
            color = c
            needsDisplay = true
            onPick?(c)
        }
    }
}

/// A titled container that renders reliably in an accessory app's Settings
/// window (where grouped `Form`/`TabView` content can come up blank).
private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
