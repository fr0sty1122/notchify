import Foundation

enum IslandMode: String, CaseIterable, Identifiable {
    case media
    case calendar
    case mirror
    case shelf
    case notes
    case clipboard

    var id: String { rawValue }
}

struct MediaTrack: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var source: String
    var isPlaying: Bool
    var artworkLocation: String?
    var playbackPosition: Double
    var duration: Double
    var sampledAt: Date = Date()

    static let empty = MediaTrack(
        title: "Nothing Playing",
        artist: "Open Apple Music or Spotify",
        album: "",
        source: "Media",
        isPlaying: false,
        artworkLocation: nil,
        playbackPosition: 0,
        duration: 0
    )

    /// Position interpolated forward from the last sample using elapsed wall
    /// time, so the scrubber advances smoothly between the (slow) polls.
    func interpolatedPosition(at date: Date = Date()) -> Double {
        guard isPlaying else { return playbackPosition }
        let elapsed = date.timeIntervalSince(sampledAt)
        let projected = playbackPosition + max(0, elapsed)
        return duration > 0 ? min(projected, duration) : projected
    }

    /// True when a real track is loaded (playing OR paused), as opposed to the
    /// empty placeholder. Used so the compact pill stays put across play/pause
    /// instead of appearing/disappearing (which caused layout stutter).
    var isActive: Bool {
        source == "Apple Music" || source == "Spotify"
    }
}

struct ShelfItem: Identifiable, Equatable {
    let id = UUID()
    var url: URL
    var addedAt: Date
    var displayName: String { url.lastPathComponent }
}

struct ClipboardEntry: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var copiedAt: Date
}

struct NoteItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String = ""
    var text: String
    var createdAt: Date
    var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id, title, text, createdAt, updatedAt
    }

    init(id: UUID = UUID(), title: String = "", text: String = "", createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom decoder so notes saved before `title` existed still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Row title: the user's title if set, otherwise the first body line.
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }
        let trimmedBody = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let firstLine = trimmedBody.split(whereSeparator: \.isNewline).first,
              !firstLine.isEmpty else {
            return "New Note"
        }
        return String(firstLine)
    }

    /// Row preview: the body text condensed to a single line. When the note
    /// has no explicit title, the first body line is used as the title, so it
    /// is dropped from the preview to avoid showing it twice.
    var snippet: String {
        let hasTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let lines = text.split(whereSeparator: \.isNewline)
        let preview = hasTitle ? lines[...] : lines.dropFirst()
        return preview.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when neither the title nor body has any content.
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum ClipboardRetention: Int, CaseIterable, Identifiable {
    case tenSeconds = 10
    case tenMinutes = 600
    case oneHour = 3600
    case sixHours = 21600
    case twentyFourHours = 86400

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .tenSeconds: return "10 seconds"
        case .tenMinutes: return "10 minutes"
        case .oneHour: return "1 hour"
        case .sixHours: return "6 hours"
        case .twentyFourHours: return "24 hours"
        }
    }
}

