import AppKit
import AVFoundation
import SwiftUI

struct MediaIslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AlbumArtwork(track: viewModel.media)
                .frame(width: 97, height: 97)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.media.title)
                            .font(.system(size: 13, weight: .bold))
                            .lineLimit(1)
                        Text(viewModel.media.artist)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                }

                if viewModel.media.duration > 0 {
                    TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                        MediaScrubber(
                            position: viewModel.media.interpolatedPosition(),
                            duration: viewModel.media.duration,
                            onSeek: { viewModel.seek(to: $0) }
                        )
                    }
                }

                HStack(spacing: 20) {
                    Spacer(minLength: 0)
                    MediaButton(systemName: "backward.fill", action: viewModel.previousTrack)
                    MediaButton(systemName: viewModel.media.isPlaying ? "pause.fill" : "play.fill", action: viewModel.playPause)
                        .controlSize(.large)
                    MediaButton(systemName: "forward.fill", action: viewModel.nextTrack)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct MediaScrubber: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragFraction: Double = 0

    private let trackHeight: CGFloat = 5
    private let hitHeight: CGFloat = 20

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                let fraction = isDragging ? dragFraction : safeFraction
                let knobX = max(0, min(width, width * fraction))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.22))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(width: knobX, height: trackHeight)

                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 14 : 11, height: isDragging ? 14 : 11)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                        .offset(x: knobX - (isDragging ? 7 : 5.5))
                }
                .frame(height: hitHeight)
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragFraction = max(0, min(1, value.location.x / width))
                        }
                        .onEnded { value in
                            let finalFraction = max(0, min(1, value.location.x / width))
                            dragFraction = finalFraction
                            onSeek(finalFraction * duration)
                            isDragging = false
                        }
                )
                .animation(.easeOut(duration: 0.12), value: isDragging)
            }
            .frame(height: hitHeight)
            .padding(.horizontal, 6)

            HStack {
                Text(timeString(isDragging ? dragFraction * duration : position))
                Spacer()
                Text(timeString(duration))
            }
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            .monospacedDigit()
            .padding(.horizontal, 6)
        }
    }

    private var safeFraction: Double {
        guard duration > 0 else { return 0 }
        return max(0, min(1, position / duration))
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct CalendarIslandView: View {
    var accent: Color = .white
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(monthYearText)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(todayText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Cell height scales down for 6-week months so the grid never runs
            // off the bottom of the island.
            let rows = max(1, monthDays.count / 7)
            let cellH: CGFloat = rows >= 6 ? 22 : 26

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 3) {
                ForEach(monthDays.indices, id: \.self) { index in
                    if let day = monthDays[index] {
                        let isToday = calendar.isDateInToday(day)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 12, weight: isToday ? .heavy : .semibold, design: .rounded))
                            .foregroundStyle(isToday ? Color.black : .white.opacity(0.78))
                            .frame(maxWidth: .infinity)
                            .frame(height: cellH)
                            .background(isToday ? accent : .clear, in: Capsule())
                    } else {
                        Color.clear.frame(height: cellH)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var monthYearText: String {
        DateFormatter.calendarMonthYear.string(from: Date())
    }

    private var todayText: String {
        DateFormatter.calendarWeekdayDay.string(from: Date())
    }

    private var weekdaySymbols: [String] {
        Array(calendar.shortStandaloneWeekdaySymbols.map { String($0.prefix(1)) })
    }

    private var monthDays: [Date?] {
        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1)) else {
            return []
        }

        var days: [Date?] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(calendar.isDate(cursor, equalTo: monthInterval.start, toGranularity: .month) ? cursor : nil)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? lastWeek.end
        }
        return days
    }
}

struct MirrorIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject private var camera: CameraService

    init(viewModel: IslandViewModel) {
        self.viewModel = viewModel
        _camera = ObservedObject(wrappedValue: viewModel.cameraService)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Mirror")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if camera.status == .running {
                    Button { camera.stop() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.06))

                switch camera.status {
                case .running:
                    CameraPreview(previewLayer: camera.previewLayer)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                case .stopped:
                    MirrorMessage(
                        icon: "camera.fill",
                        title: "Tap to enable camera",
                        subtitle: camera.isAuthorized ? nil : "macOS will ask for camera permission the first time."
                    )
                case .starting:
                    MirrorMessage(icon: "camera.fill", title: "Starting camera...")
                case .denied:
                    MirrorMessage(
                        icon: "video.slash",
                        title: "Camera access needed",
                        subtitle: "Enable Notchify in System Settings > Privacy & Security > Camera."
                    )
                case .unavailable:
                    MirrorMessage(icon: "video.slash", title: "No camera available")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(camera.status == .stopped ? 0.22 : 0.1),
                            style: StrokeStyle(lineWidth: camera.status == .stopped ? 1.2 : 0.8,
                                               dash: camera.status == .stopped ? [6, 4] : []))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                // Tapping the designated area enables (or re-enables) the camera.
                if camera.status == .stopped { camera.start() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Leaving the mirror (switching tabs or collapsing the island) tears
        // this view down, which stops the camera. Re-entering shows the
        // tap-to-enable prompt again.
        .onDisappear { camera.stop() }
    }
}

private struct MirrorMessage: View {
    let icon: String
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
        }
        .padding(12)
    }
}

private struct CameraPreview: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> PreviewNSView {
        PreviewNSView(previewLayer: previewLayer)
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {
        nsView.attach(previewLayer)
    }

    final class PreviewNSView: NSView {
        private var previewLayer: AVCaptureVideoPreviewLayer

        init(previewLayer: AVCaptureVideoPreviewLayer) {
            self.previewLayer = previewLayer
            super.init(frame: .zero)
            wantsLayer = true
            layer = CALayer()
            // Detach from any previous host before re-adding.
            previewLayer.removeFromSuperlayer()
            previewLayer.frame = bounds
            layer?.addSublayer(previewLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        /// Re-host the (persistent) preview layer if SwiftUI recreated the view.
        func attach(_ newLayer: AVCaptureVideoPreviewLayer) {
            guard newLayer !== previewLayer else {
                previewLayer.frame = bounds
                return
            }
            previewLayer.removeFromSuperlayer()
            previewLayer = newLayer
            newLayer.removeFromSuperlayer()
            newLayer.frame = bounds
            layer?.addSublayer(newLayer)
        }

        override func layout() {
            super.layout()
            previewLayer.frame = bounds
        }
    }
}

struct ShelfIslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Temporary Shelf")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(viewModel.shelfItems.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            if viewModel.shelfItems.isEmpty {
                EmptyState(icon: "tray.and.arrow.down", title: "Drop files on the island")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                    ForEach(viewModel.shelfItems) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "doc")
                            Text(item.displayName)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button { viewModel.removeShelfItem(item) } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onDrag {
                            let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
                            // Use the base name without extension; the system
                            // re-appends the proper extension from the file's
                            // type, so passing the full name caused "abc.xlsx.xlsx".
                            provider.suggestedName = item.url.deletingPathExtension().lastPathComponent
                            return provider
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct NotesIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var selectedNoteID: NoteItem.ID?

    private var selectedNote: NoteItem? {
        guard let selectedNoteID else { return nil }
        return viewModel.notes.first { $0.id == selectedNoteID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let note = selectedNote {
                NoteEditor(
                    note: note,
                    onTitleChange: { viewModel.updateNote(note.id, title: $0) },
                    onTextChange: { viewModel.updateNote(note.id, text: $0) },
                    onClose: { withAnimation(.islandSnappy) { selectedNoteID = nil } },
                    onDelete: {
                        viewModel.removeNote(note.id)
                        withAnimation(.islandSnappy) { selectedNoteID = nil }
                    }
                )
            } else if viewModel.notes.isEmpty {
                EmptyState(icon: "note.text", title: "Tap + to jot a quick note")
            } else {
                noteList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        HStack {
            Text("Quick Notes")
                .font(.system(size: 15, weight: .bold))
            Spacer()
            if selectedNote == nil {
                Text("\(viewModel.notes.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            Button {
                let note = viewModel.addNote()
                withAnimation(.islandSnappy) { selectedNoteID = note.id }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 22)
                    .background(.white.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("New note")
        }
        // Align the add button above the per-row delete buttons: rows have an
        // 8pt internal padding inside the list's 14pt trailing inset.
        .padding(.trailing, selectedNote == nil ? 15 : 0)
    }

    private var noteList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.notes) { note in
                    NoteRow(
                        note: note,
                        onOpen: { withAnimation(.islandSnappy) { selectedNoteID = note.id } },
                        onDelete: { viewModel.removeNote(note.id) }
                    )
                }
            }
            .padding(.trailing, 14)
        }
        .scrollIndicators(.visible)
    }
}

private struct NoteRow: View {
    let note: NoteItem
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    if !note.snippet.isEmpty {
                        Text(note.snippet)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Text(note.updatedAt, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }
            .padding(8)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NoteEditor: View {
    let note: NoteItem
    let onTitleChange: (String) -> Void
    let onTextChange: (String) -> Void
    let onClose: () -> Void
    let onDelete: () -> Void

    @State private var title: String
    @State private var text: String
    @FocusState private var focus: Field?

    private enum Field { case title, body }

    init(
        note: NoteItem,
        onTitleChange: @escaping (String) -> Void,
        onTextChange: @escaping (String) -> Void,
        onClose: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.note = note
        self.onTitleChange = onTitleChange
        self.onTextChange = onTextChange
        self.onClose = onClose
        self.onDelete = onDelete
        _title = State(initialValue: note.title)
        _text = State(initialValue: note.text)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Button(action: onClose) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text("All Notes")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Delete note")
            }

            TextField("Title", text: $title)
                .textFieldStyle(.plain)
                .focused($focus, equals: .title)
                .font(.system(size: 13, weight: .bold))
                .submitLabel(.next)
                .onSubmit { focus = .body }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .onChange(of: title) { _, newValue in onTitleChange(newValue) }

            TextEditor(text: $text)
                .focused($focus, equals: .body)
                .font(.system(size: 12, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxHeight: .infinity)
                .onChange(of: text) { _, newValue in onTextChange(newValue) }
        }
        .onAppear { focus = note.title.isEmpty && note.text.isEmpty ? .title : .body }
    }
}

struct ClipboardIslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clipboard")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text("\(viewModel.clipboardEntries.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                if !viewModel.clipboardEntries.isEmpty {
                    Button {
                        withAnimation(.islandSnappy) { viewModel.clearClipboard() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clear")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Clear clipboard history")
                }
            }
            if viewModel.clipboardEntries.isEmpty {
                EmptyState(icon: "doc.on.clipboard", title: "Copy text to build history")
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.clipboardEntries) { entry in
                            ClipboardRow(entry: entry, onCopy: {
                                viewModel.copy(entry)
                            }, onDelete: {
                                withAnimation(.islandSnappy) { viewModel.removeClipboardEntry(entry) }
                            })
                        }
                    }
                    .padding(.trailing, 14)
                }
                .scrollIndicators(.visible)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Button {
                onCopy()
                withAnimation(.easeOut(duration: 0.15)) { didCopy = true }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    withAnimation(.easeOut(duration: 0.2)) { didCopy = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    Text(didCopy ? "Copied" : "Copy")
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.white.opacity(didCopy ? 0.22 : 0.14))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Remove from history")
        }
        .padding(8)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AlbumArtwork: View {
    let track: MediaTrack

    var body: some View {
        AlbumArtworkImage(location: track.artworkLocation, cornerRadius: 16)
    }
}

/// Loads + decodes local artwork off the main thread and caches the result so
/// SwiftUI body evaluation (which can happen many times per second) never
/// blocks on disk I/O. Decoding inline was the cause of play/pause stutter.
final class ArtworkCache {
    static let shared = ArtworkCache()
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "com.pratik.notchify.artwork", qos: .userInitiated)

    func cachedImage(for path: String) -> NSImage? {
        cache.object(forKey: path as NSString)
    }

    func loadImage(for path: String, completion: @escaping (NSImage?) -> Void) {
        if let cached = cache.object(forKey: path as NSString) {
            completion(cached)
            return
        }
        queue.async { [weak self] in
            let image = NSImage(contentsOfFile: path)
            if let image { self?.cache.setObject(image, forKey: path as NSString) }
            DispatchQueue.main.async { completion(image) }
        }
    }
}

struct AlbumArtworkImage: View {
    let location: String?
    let cornerRadius: CGFloat
    @State private var loadedImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [.teal, .indigo, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))

            if let loadedImage {
                Image(nsImage: loadedImage)
                    .resizable()
                    .scaledToFill()
            } else if let url = remoteURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear(perform: refresh)
        .onChange(of: location) { _, _ in refresh() }
    }

    private func refresh() {
        guard let location, !location.hasPrefix("http") else {
            loadedImage = nil
            return
        }
        // Show the cached image immediately if we have it; otherwise load async
        // without blocking the main thread.
        if let cached = ArtworkCache.shared.cachedImage(for: location) {
            loadedImage = cached
            return
        }
        ArtworkCache.shared.loadImage(for: location) { image in
            self.loadedImage = image
        }
    }

    private var remoteURL: URL? {
        guard let location, location.hasPrefix("http") else { return nil }
        return URL(string: location)
    }
}

struct AudioBars: View {
    let isPlaying: Bool
    var color: Color = .white

    private let barCount = 5
    // Per-bar oscillation speeds and phase offsets give an organic,
    // music-reactive motion rather than a uniform sweep.
    private let speeds: [Double] = [2.7, 3.6, 2.1, 4.2, 3.1]
    private let phases: [Double] = [0.0, 1.1, 2.3, 0.6, 1.8]

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(isPlaying ? color : color.opacity(0.4))
                        .frame(width: 2, height: height(for: index, at: t))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: isPlaying)
        }
    }

    private func height(for index: Int, at time: TimeInterval) -> CGFloat {
        let maxHeight: CGFloat = 13
        let minHeight: CGFloat = 3
        guard isPlaying else { return minHeight }
        // Combine two sine waves per bar for a less repetitive, lively motion.
        let wave = sin(time * speeds[index] + phases[index])
        let wobble = sin(time * (speeds[index] * 1.9) + phases[index] * 2)
        let normalized = (wave * 0.7 + wobble * 0.3 + 1) / 2 // 0...1
        return minHeight + (maxHeight - minHeight) * CGFloat(normalized)
    }
}

private struct MediaButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyState: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension DateFormatter {
    static let calendarMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let calendarWeekdayDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter
    }()
}
