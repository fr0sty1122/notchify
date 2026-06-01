import SwiftUI

struct IslandRootView: View {
    @ObservedObject var viewModel: IslandViewModel
    @State private var isDropTargeted = false

    var body: some View {
        ZStack(alignment: .top) {
            islandContent
        }
        .frame(width: viewModel.panelSize.width, height: viewModel.panelSize.height, alignment: .top)
        .contentShape(Rectangle())
        .animation(.islandResize, value: viewModel.islandSize)
        .animation(.islandResize, value: viewModel.isExpanded)
        .animation(.islandContent, value: viewModel.mode)
        .animation(.islandQuick, value: viewModel.shouldShowCompactPlayer)
        .onTapGesture { viewModel.openFromInteraction() }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor in viewModel.addShelfItems([url]) }
                }
            }
            return true
        }
    }

    /// The island content: collapsed notch, compact player, or expanded panel.
    private var islandContent: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                if viewModel.isExpanded {
                    NotchShape(topCornerRadius: 18, bottomCornerRadius: 24)
                        .fill(.black)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(.black)
                                .frame(height: 1)
                                .padding(.horizontal, 18)
                        }
                        .overlay {
                            NotchShape(topCornerRadius: 18, bottomCornerRadius: 24)
                                .stroke(.white.opacity(0.08), lineWidth: 0.8)
                        }
                        .shadow(color: .black.opacity(0.62), radius: 13, y: 8)
                        .transition(.opacity)

                    ExpandedIslandView(viewModel: viewModel)
                        .padding(.horizontal, viewModel.mode == .media ? 16 : 24)
                        .padding(.top, 2)
                        .padding(.bottom, viewModel.mode == .media ? 12 : 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else if viewModel.shouldShowCompactPlayer {
                    CompactMediaLiveActivity(viewModel: viewModel)
                        .frame(width: viewModel.islandSize.width, height: viewModel.islandSize.height)
                        .transition(.opacity)
                } else if isDropTargeted {
                    Capsule()
                        .fill(.teal.opacity(0.28))
                        .frame(width: 72, height: 4)
                        .padding(.top, max(6, viewModel.notchSize.height - 7))
                        .transition(.opacity)
                }
            }
            .frame(width: viewModel.islandSize.width, height: viewModel.islandSize.height, alignment: .top)
            .clipShape(NotchShape(topCornerRadius: viewModel.isExpanded ? 18 : 6, bottomCornerRadius: viewModel.isExpanded ? 24 : 14))
        }
    }
}

private struct CompactMediaLiveActivity: View {
    @ObservedObject var viewModel: IslandViewModel

    var body: some View {
        HStack(spacing: 0) {
            AlbumArtworkImage(location: viewModel.media.artworkLocation, cornerRadius: 7)
                .frame(width: max(20, viewModel.notchSize.height - 8), height: max(20, viewModel.notchSize.height - 8))
                .padding(.leading, 11)
            Spacer(minLength: viewModel.notchSize.width)
            if viewModel.settings.showEqualizer {
                AudioBars(isPlaying: viewModel.media.isPlaying, color: viewModel.settings.accentColor)
                    .frame(width: 18, height: min(14, viewModel.notchSize.height - 8))
                    .padding(.trailing, 16)
            } else {
                Color.clear.frame(width: 1).padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .clipShape(NotchShape(topCornerRadius: 6, bottomCornerRadius: 14))
    }
}

private struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        // Subtle concave top corners that flare outward into the flat top edge
        // (like the real MacBook notch), with convex rounded bottom corners.
        // The concave radius is kept small/capped so the curve stays slight.
        let topR = min(topCornerRadius, 9, rect.width / 2, rect.height)
        let bottomR = min(bottomCornerRadius, (rect.width - 2 * topR) / 2, rect.height - topR)

        var path = Path()

        // Top-left outer edge, curving down & inward (concave).
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
            control: CGPoint(x: rect.minX + topR, y: rect.minY)
        )

        // Left inner edge down to the convex bottom-left corner.
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - bottomR))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR + bottomR, y: rect.maxY),
            control: CGPoint(x: rect.minX + topR, y: rect.maxY)
        )

        // Bottom edge to the convex bottom-right corner.
        path.addLine(to: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topR, y: rect.maxY - bottomR),
            control: CGPoint(x: rect.maxX - topR, y: rect.maxY)
        )

        // Right inner edge up to the concave top-right corner.
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topR, y: rect.minY)
        )

        // Flat top edge back to start.
        path.closeSubpath()
        return path
    }
}
