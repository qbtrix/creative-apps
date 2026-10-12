// CanvasSurface.swift: the content layer of a canvas app: a neutral surround
// with the artboard centered and scaled to fit, plus an optional floating
// overlay (a ToolbarGroup palette or a GlassPanel) pinned to one edge. The
// surround and artboard are flat; only the overlay may be glass.
import SwiftUI

public struct CanvasSurface<Overlay: View>: View {
    private let artboard: CGSize
    private let overlayAlignment: Alignment
    private let overlay: Overlay

    /// `artboard` is the document's size in points; non-positive sides draw
    /// as 1 point so the aspect ratio stays defined.
    public init(
        artboard: CGSize, overlayAlignment: Alignment = .leading,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.artboard = CGSize(width: max(artboard.width, 1), height: max(artboard.height, 1))
        self.overlayAlignment = overlayAlignment
        self.overlay = overlay()
    }

    public var body: some View {
        ZStack {
            SuiteColor.canvasSurround
            Rectangle()
                .fill(SuiteColor.artboard)
                .aspectRatio(artboard, contentMode: .fit)
                .frame(maxWidth: artboard.width, maxHeight: artboard.height)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                .padding(SuiteSpacing.xxl * 2)
        }
        .overlay(alignment: overlayAlignment) {
            overlay.padding(SuiteSpacing.l)
        }
    }
}

extension CanvasSurface where Overlay == EmptyView {
    public init(artboard: CGSize) {
        self.init(artboard: artboard) { EmptyView() }
    }
}
