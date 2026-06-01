import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let mediaMonitor = MediaMonitor()
    let shelfService = TemporaryShelfService()
    let clipboardService = ClipboardHistoryService()
    let notesService = NotesService()
    let cameraService = CameraService()
    let loginItemService = LoginItemService()
    let settings = SettingsStore()

    lazy var viewModel = IslandViewModel(
        mediaMonitor: mediaMonitor,
        shelfService: shelfService,
        clipboardService: clipboardService,
        notesService: notesService,
        cameraService: cameraService,
        settings: settings
    )

    private var overlayPanel: OverlayPanel?
    private var positioningService: WindowPositioningService?
    private var hoverMonitor: NotchHoverMonitor?
    private var hotKeyController: HotKeyController?
    private var preferencesWindow: PreferencesWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panel = OverlayPanel(rootView: IslandRootView(viewModel: viewModel))
        overlayPanel = panel

        let positioner = WindowPositioningService(panel: panel)
        positioningService = positioner
        viewModel.updateNotchSize(for: NSScreen.main)
        positioner.reposition(for: viewModel.panelSize)

        hoverMonitor = NotchHoverMonitor(
            panel: panel,
            islandFrameProvider: { [weak self] in self?.viewModel.screenIslandFrame(in: panel.frame) ?? panel.frame },
            onHoverChange: { [weak self] hovering in self?.viewModel.hover(hovering) },
            onScreenChange: { [weak self] screen in
                self?.viewModel.updateNotchSize(for: screen)
                self?.positioningService?.reposition(for: self?.viewModel.panelSize ?? NotchMetrics.maxPanelSize)
            }
        )
        hoverMonitor?.triggerPaddingProvider = { [weak self] in CGFloat(self?.settings.hoverTriggerSize ?? 12) }
        hoverMonitor?.collapseDelayProvider = { [weak self] in self?.settings.autoCollapseDelay ?? 0.16 }
        hoverMonitor?.start()

        hotKeyController = HotKeyController { [weak self] in
            Task { @MainActor in self?.viewModel.toggleExpanded() }
        }
        hotKeyController?.register()

        viewModel.$panelSize
            .sink { [weak self] size in self?.positioningService?.reposition(for: size) }
            .store(in: &cancellables)

        viewModel.$isExpanded
            .removeDuplicates()
            .sink { [weak panel] expanded in panel?.ignoresMouseEvents = !expanded }
            .store(in: &cancellables)

        // Keep the login-item registration in sync with the setting, and seed
        // the setting from the service's current state on first launch.
        settings.launchAtLogin = loginItemService.isEnabled
        settings.$launchAtLogin
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled != self.loginItemService.isEnabled {
                    self.loginItemService.setEnabled(enabled)
                }
            }
            .store(in: &cancellables)

        mediaMonitor.start()
        clipboardService.start()

        // Launching the app (from Applications/Finder) opens Preferences. The
        // notch stays collapsed until the user hovers it or uses the shortcut.
        showPreferences()
    }

    /// Clicking the app icon in Finder/Dock while it's already running brings
    /// Preferences forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKeyController?.unregister()
        hoverMonitor?.stop()
        mediaMonitor.stop()
    }

    private func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindowController(viewModel: viewModel)
        }
        preferencesWindow?.show()
    }
}
