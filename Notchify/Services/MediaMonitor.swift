import Combine
import Foundation

/// Polls Apple Music / Spotify for now-playing info.
///
/// All scripting and disk work happens on a background queue; only the
/// published `track` is delivered on the main thread, so play/pause never
/// blocks the UI. Scripts run via the `osascript` process rather than
/// `NSAppleScript` because `NSAppleScript` is main-thread-only and crashes
/// when driven from a background queue.
final class MediaMonitor: ObservableObject {
    @Published private(set) var track = MediaTrack.empty

    private let queue = DispatchQueue(label: "com.pratik.notchify.media", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var observers: [NSObjectProtocol] = []

    // Touched only on `queue`.
    private var artworkPaths: [String] = []
    private let maxArtworkFiles = 5
    private var lastSource = "Music"
    /// Coalesces bursty poll requests: at most one poll is queued ahead.
    private var pollPending = false

    private static let musicNotification = "com.apple.Music.playerInfo"
    private static let iTunesNotification = "com.apple.iTunes.playerInfo"
    private static let spotifyNotification = "com.spotify.client.PlaybackStateChanged"

    func start() {
        requestPoll()
        // Slow safety-net poll; real-time updates come from notifications.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2.5, repeating: 2.5)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
        observePlayerNotifications()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        let center = DistributedNotificationCenter.default()
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
        queue.async { [weak self] in
            guard let self else { return }
            for path in self.artworkPaths {
                try? FileManager.default.removeItem(atPath: path)
            }
            self.artworkPaths.removeAll()
        }
    }

    private func observePlayerNotifications() {
        let center = DistributedNotificationCenter.default()
        let names = [Self.musicNotification, Self.iTunesNotification, Self.spotifyNotification]
        observers = names.map { name in
            center.addObserver(forName: Notification.Name(name), object: nil, queue: nil) { [weak self] _ in
                self?.requestPoll()
            }
        }
    }

    // MARK: Transport (fire-and-forget on the background queue)

    func playPause() { sendCommand("playpause") }
    func next() { sendCommand("next track") }
    func previous() { sendCommand("previous track") }

    func seek(to seconds: Double) {
        let target = max(0, seconds)
        queue.async { [weak self] in
            guard let self else { return }
            let appName = self.lastSource == "Spotify" ? "Spotify" : "Music"
            _ = self.runAppleScript("""
            if application "\(appName)" is running then
              tell application "\(appName)" to set player position to \(target)
            end if
            """)
            self.poll()
        }
    }

    private func sendCommand(_ command: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let appName = self.lastSource == "Spotify" ? "Spotify" : "Music"
            _ = self.runAppleScript("""
            if application "\(appName)" is running then
              tell application "\(appName)" to \(command)
            end if
            """)
            self.requestPoll()
        }
    }

    // MARK: Polling (runs on `queue`)

    /// Coalesced poll: collapses a burst of requests (e.g. a transport command
    /// plus the player's change notification) into a single refresh.
    private func requestPoll() {
        queue.async { [weak self] in
            guard let self, !self.pollPending else { return }
            self.pollPending = true
            self.queue.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self else { return }
                self.pollPending = false
                self.poll()
            }
        }
    }

    private func poll() {
        let music = readMusic()
        let spotify = readSpotify()

        let newTrack: MediaTrack
        if let music, music.isPlaying {
            newTrack = music
        } else if let spotify, spotify.isPlaying {
            newTrack = spotify
        } else if let music, music.title != "" {
            newTrack = music
        } else if let spotify, spotify.title != "" {
            newTrack = spotify
        } else {
            newTrack = .empty
        }

        lastSource = newTrack.source
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.track != newTrack { self.track = newTrack }
        }
    }

    private func readMusic() -> MediaTrack? {
        let script = """
        if application "Music" is running then
          tell application "Music"
            if player state is stopped then return ""
            set tid to ""
            try
              set tid to (database ID of current track) as string
            end try
            return name of current track & "\n" & artist of current track & "\n" & album of current track & "\nApple Music\n" & (player state is playing) & "\n" & tid & "\n" & player position & "\n" & duration of current track
          end tell
        end if
        return ""
        """
        guard let output = runAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 5 else { return nil }

        let trackKey = parts.count >= 6 ? parts[5] : ""
        let artworkPath = artworkPathForMusic(key: trackKey, title: parts[0], artist: parts[1])

        return MediaTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            source: parts[3],
            isPlaying: parts[4].localizedCaseInsensitiveContains("true"),
            artworkLocation: artworkPath,
            playbackPosition: parts.count >= 7 ? (Double(parts[6]) ?? 0) : 0,
            duration: parts.count >= 8 ? (Double(parts[7]) ?? 0) : 0
        )
    }

    /// Returns a per-track artwork file path, writing the image only the first
    /// time a given track is seen. Unique paths let SwiftUI reload the image
    /// when the track changes. Runs on `queue`.
    private func artworkPathForMusic(key: String, title: String, artist: String) -> String? {
        let rawID = key.isEmpty ? "\(title)-\(artist)" : key
        let safeID = rawID.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
        guard !safeID.isEmpty else { return nil }

        let path = "/tmp/notchify-art-\(safeID).jpg"
        if FileManager.default.fileExists(atPath: path) {
            if let index = artworkPaths.firstIndex(of: path) {
                artworkPaths.remove(at: index)
            }
            artworkPaths.append(path)
            return path
        }

        _ = runAppleScript("""
        if application "Music" is running then
          tell application "Music"
            try
              if (count of artworks of current track) > 0 then
                set artworkData to data of artwork 1 of current track
                set artworkFile to open for access POSIX file "\(path)" with write permission
                set eof artworkFile to 0
                write artworkData to artworkFile
                close access artworkFile
              end if
            end try
          end tell
        end if
        """)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        artworkPaths.append(path)
        pruneArtworkFiles()
        return path
    }

    /// Keep only the most recent `maxArtworkFiles` artwork files in /tmp.
    private func pruneArtworkFiles() {
        guard artworkPaths.count > maxArtworkFiles else { return }
        let overflow = artworkPaths.count - maxArtworkFiles
        for path in artworkPaths.prefix(overflow) {
            try? FileManager.default.removeItem(atPath: path)
        }
        artworkPaths.removeFirst(overflow)
    }

    private func readSpotify() -> MediaTrack? {
        let script = """
        if application "Spotify" is running then
          tell application "Spotify"
            if player state is stopped then return ""
            return name of current track & "\n" & artist of current track & "\n" & album of current track & "\nSpotify\n" & (player state is playing) & "\n" & artwork url of current track & "\n" & player position & "\n" & ((duration of current track) / 1000)
          end tell
        end if
        return ""
        """
        return parse(runAppleScript(script))
    }

    private func parse(_ output: String?) -> MediaTrack? {
        guard let output, !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "\n")
        guard parts.count >= 5 else { return nil }
        return MediaTrack(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            source: parts[3],
            isPlaying: parts[4].localizedCaseInsensitiveContains("true"),
            artworkLocation: parts.count >= 6 && !parts[5].isEmpty ? parts[5] : nil,
            playbackPosition: parts.count >= 7 ? (Double(parts[6]) ?? 0) : 0,
            duration: parts.count >= 8 ? (Double(parts[7]) ?? 0) : 0
        )
    }

    /// Runs AppleScript via the `osascript` process. Thread-safe (unlike
    /// `NSAppleScript`) and isolated from the app, so a scripting hiccup can't
    /// crash us. Must only be called from `queue`.
    private func runAppleScript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            NSLog("osascript launch failed: \(error.localizedDescription)")
            return nil
        }

        if let data = source.data(using: .utf8) {
            stdin.fileHandleForWriting.write(data)
        }
        stdin.fileHandleForWriting.closeFile()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let raw = String(data: outData, encoding: .utf8) else { return nil }
        // osascript appends a trailing newline to the printed result.
        if raw.hasSuffix("\n") { return String(raw.dropLast()) }
        return raw
    }
}
