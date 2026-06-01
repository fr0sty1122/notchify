import Combine
import Foundation

@MainActor
final class NotesService: ObservableObject {
    @Published private(set) var notes: [NoteItem] = []

    private static let storageKey = "quickNotes"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    @discardableResult
    func addNote(_ text: String = "") -> NoteItem {
        let now = Date()
        let note = NoteItem(text: text, createdAt: now, updatedAt: now)
        notes.insert(note, at: 0)
        persist()
        return note
    }

    func update(_ id: NoteItem.ID, title: String? = nil, text: String? = nil) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        var changed = false
        if let title, notes[index].title != title {
            notes[index].title = title
            changed = true
        }
        if let text, notes[index].text != text {
            notes[index].text = text
            changed = true
        }
        guard changed else { return }
        notes[index].updatedAt = Date()
        persist()
    }

    func remove(_ id: NoteItem.ID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    /// Drops notes that were never given any content (e.g. a blank note the
    /// user opened but didn't type into before closing the island).
    func discardEmptyNotes() {
        let filtered = notes.filter { !$0.isEmpty }
        guard filtered.count != notes.count else { return }
        notes = filtered
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) else { return }
        notes = decoded
    }
}
