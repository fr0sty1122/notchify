import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var mode: IslandMode = .media
    @Published var isExpanded = false
    @Published var isHovering = false
    @Published private(set) var panelSize = NotchMetrics.maxPanelSize
    @Published private(set) var notchSize = NotchMetrics.closedNotchSize(on: NSScreen.main)
    @Published private(set) var media = MediaTrack.empty
    @Published private(set) var shelfItems: [ShelfItem] = []
    @Published private(set) var clipboardEntries: [ClipboardEntry] = []
    @Published private(set) var notes: [NoteItem] = []

    private let mediaMonitor: MediaMonitor
    private let shelfService: TemporaryShelfService
    private let clipboardService: ClipboardHistoryService
    private let notesService: NotesService
    let cameraService: CameraService
    let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(
        mediaMonitor: MediaMonitor,
        shelfService: TemporaryShelfService,
        clipboardService: ClipboardHistoryService,
        notesService: NotesService,
        cameraService: CameraService,
        settings: SettingsStore
    ) {
        self.mediaMonitor = mediaMonitor
        self.shelfService = shelfService
        self.clipboardService = clipboardService
        self.notesService = notesService
        self.cameraService = cameraService
        self.settings = settings
        bind()
    }

    var islandSize: CGSize {
        guard isExpanded else {
            if shouldShowCompactPlayer {
                return CGSize(width: max(notchSize.width + 78, 244), height: notchSize.height + 1)
            }
            return notchSize
        }
        switch mode {
        case .media:
            return CGSize(width: 480, height: 180)
        case .calendar:
            return CGSize(width: 450, height: 260)
        case .mirror:
            return CGSize(width: 450, height: 240)
        case .shelf:
            return CGSize(width: 450, height: 240)
        case .notes:
            return CGSize(width: 450, height: 240)
        case .clipboard:
            return CGSize(width: 450, height: 240)
        }
    }

    /// Whether the collapsed now-playing pill should be shown right now.
    /// Honors the master toggle and the "keep while paused" preference.
    var shouldShowCompactPlayer: Bool {
        guard settings.showCompactMedia, media.isActive else { return false }
        return media.isPlaying || settings.keepPlayerWhilePaused
    }

    func screenIslandFrame(in panelFrame: NSRect) -> NSRect {
        let size = islandSize
        return NSRect(
            x: panelFrame.midX - size.width / 2,
            y: panelFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    func updateNotchSize(for screen: NSScreen?) {
        let newSize = NotchMetrics.closedNotchSize(on: screen)
        guard newSize != notchSize else { return }
        withAnimation(.islandResize) {
            notchSize = newSize
        }
    }

    func hover(_ hovering: Bool) {
        if hovering {
            guard settings.expandOnHover else { return }
            withAnimation(.islandResize) {
                isHovering = true
                isExpanded = true
            }
        } else {
            withAnimation(.islandResize) {
                isHovering = false
                isExpanded = false
            }
        }
    }

    func toggleExpanded() {
        withAnimation(.islandResize) {
            isExpanded.toggle()
            isHovering = isExpanded
        }
    }

    func openFromInteraction() {
        guard !isExpanded else { return }
        hover(true)
    }

    func setMode(_ newMode: IslandMode) {
        withAnimation(.islandContent) {
            mode = newMode
            isExpanded = true
        }
    }

    /// React to preference changes: keep services in sync and bail off any tab
    /// the user just turned off.
    private func handleSettingsChange() {
        clipboardService.maxItems = settings.clipboardMaxItems
        clipboardService.retention = settings.clipboardRetention
        cameraService.mirrorFlip = settings.mirrorFlip
        if !settings.isTabEnabled(mode) {
            withAnimation(.islandContent) { mode = .media }
        }
    }

    func addShelfItems(_ urls: [URL]) {
        shelfService.add(urls: urls)
        setMode(.shelf)
    }

    func removeShelfItem(_ item: ShelfItem) {
        shelfService.remove(item)
    }

    @discardableResult
    func addNote() -> NoteItem {
        let note = notesService.addNote()
        setMode(.notes)
        return note
    }

    func updateNote(_ id: NoteItem.ID, title: String? = nil, text: String? = nil) {
        notesService.update(id, title: title, text: text)
    }

    func removeNote(_ id: NoteItem.ID) {
        notesService.remove(id)
    }

    func copy(_ entry: ClipboardEntry) {
        clipboardService.copy(entry)
    }

    func removeClipboardEntry(_ entry: ClipboardEntry) {
        clipboardService.remove(entry)
    }

    func clearClipboard() {
        clipboardService.clear()
    }

    func seek(to seconds: Double) {
        mediaMonitor.seek(to: seconds)
    }

    func playPause() { mediaMonitor.playPause() }
    func previousTrack() { mediaMonitor.previous() }
    func nextTrack() { mediaMonitor.next() }

    private func bind() {
        mediaMonitor.$track
            .sink { [weak self] t in
                guard let self else { return }
                if self.media != t { self.media = t }
            }
            .store(in: &cancellables)
        shelfService.$items.assign(to: &$shelfItems)
        clipboardService.$entries.assign(to: &$clipboardEntries)
        notesService.$notes.assign(to: &$notes)

        // Re-publish setting changes so dependent views (and islandSize)
        // refresh, and react to tabs being toggled off.
        settings.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                self.objectWillChange.send()
                Task { @MainActor in self.handleSettingsChange() }
            }
            .store(in: &cancellables)

        clipboardService.maxItems = settings.clipboardMaxItems
        clipboardService.retention = settings.clipboardRetention
        cameraService.mirrorFlip = settings.mirrorFlip

        $isExpanded
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in
                self?.notesService.discardEmptyNotes()
            }
            .store(in: &cancellables)

        clipboardService.$retention
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
