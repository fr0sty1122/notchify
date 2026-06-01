import SwiftUI

struct ExpandedIslandView: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        VStack(spacing: viewModel.mode == .media ? 5 : viewModel.mode == .calendar ? 7 : 12) {
            tabBar
            Group {
                switch viewModel.mode {
                case .media:
                    MediaIslandView(viewModel: viewModel)
                case .calendar:
                    CalendarIslandView(accent: viewModel.settings.accentColor)
                case .mirror:
                    MirrorIslandView(viewModel: viewModel)
                case .shelf:
                    ShelfIslandView(viewModel: viewModel)
                case .notes:
                    NotesIslandView(viewModel: viewModel)
                case .clipboard:
                    ClipboardIslandView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, contentTopClearance)
        }
    }

    private var contentTopClearance: CGFloat {
        // Icons sit beside the notch at the very top; push the content
        // below the notch so it doesn't collide with it.
        let remaining = viewModel.notchSize.height - 24
        return max(0, remaining) + (viewModel.mode == .media ? 0 : 2)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.settings.leftTabs()) { mode in
                IslandTabButton(icon: icon(for: mode), mode: mode, accent: viewModel.settings.accentColor, selection: $viewModel.mode)
            }
            Spacer()
            ForEach(viewModel.settings.rightTabs()) { mode in
                IslandTabButton(icon: icon(for: mode), mode: mode, accent: viewModel.settings.accentColor, selection: $viewModel.mode)
            }
        }
        .buttonStyle(.plain)
    }

    private func icon(for mode: IslandMode) -> String {
        switch mode {
        case .media: return "music.note"
        case .calendar: return "calendar"
        case .mirror: return "person.crop.square"
        case .shelf: return "tray.full"
        case .notes: return "note.text"
        case .clipboard: return "doc.on.clipboard"
        }
    }
}

private struct IslandTabButton: View {
    let icon: String
    let mode: IslandMode
    var accent: Color = .white
    @Binding var selection: IslandMode

    var body: some View {
        Button {
            withAnimation(.islandSnappy) {
                selection = mode
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selection == mode ? AnyShapeStyle(accent) : AnyShapeStyle(.white))
                .frame(width: 28, height: 24)
                .background(selection == mode ? accent.opacity(0.22) : .clear)
                .clipShape(Capsule())
                // Enlarge the clickable area beyond the visible capsule so
                // slightly-off clicks still register on the icon.
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .help(mode.rawValue.capitalized)
    }
}
