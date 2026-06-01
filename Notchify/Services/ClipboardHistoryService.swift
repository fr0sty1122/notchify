import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardHistoryService: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var retention: ClipboardRetention {
        didSet {
            UserDefaults.standard.set(retention.rawValue, forKey: Self.retentionKey)
            pruneExpired()
        }
    }

    private static let retentionKey = "clipboardRetentionSeconds"
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    /// Max number of entries kept; configurable from settings.
    var maxItems: Int = 15 {
        didSet {
            let clamped = max(1, maxItems)
            if entries.count > clamped {
                entries = Array(entries.prefix(clamped))
            }
        }
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.retentionKey)
        self.retention = ClipboardRetention(rawValue: stored) ?? .oneHour
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    /// Copies the entry back to the pasteboard and moves it to the top.
    func copy(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        // Keep the change count in sync so this re-copy isn't re-ingested as a
        // brand new entry on the next poll.
        lastChangeCount = pasteboard.changeCount
        if let index = entries.firstIndex(of: entry) {
            var updated = entries[index]
            updated.copiedAt = Date()
            entries.remove(at: index)
            entries.insert(updated, at: 0)
        }
    }

    /// Removes a single entry from the clipboard history.
    func remove(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    /// Clears the entire clipboard history. The current system pasteboard is
    /// left untouched, but its change count is captured so the item already on
    /// the pasteboard isn't immediately re-ingested on the next poll.
    func clear() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
        lastChangeCount = NSPasteboard.general.changeCount
    }

    private func poll() {
        pruneExpired()
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              entries.first?.text != text else { return }
        entries.insert(ClipboardEntry(text: text, copiedAt: Date()), at: 0)
        entries = Array(entries.prefix(max(1, maxItems)))
    }

    private func pruneExpired() {
        let cutoff = Date().addingTimeInterval(-retention.seconds)
        let filtered = entries.filter { $0.copiedAt > cutoff }
        if filtered.count != entries.count {
            entries = filtered
        }
    }
}

