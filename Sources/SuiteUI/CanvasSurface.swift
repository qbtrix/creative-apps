// CanvasSurface.swift: the content layer of a canvas app: a neutral surround
// with the artboard centered and scaled to fit, plus an optional floating
// overlay (a ToolbarGroup palette or a GlassPanel) pinned to one edge. The
// surround and artboard are flat; only the overlay may be glass. Where the
// artboard sits is `fitted(_:in:inset:)`, pure and tested on its own: centred,
// `canvasInset` clear of every edge, scaled down to fit and never up, sides
// that aren't positive finite numbers counted as 1, and no room giving an
// empty rect, never a division by zero. Apps that lay their own marks over
// the artboard (Halo's viewer, Library's loupe) call it too, as
// `CanvasSurface<EmptyView>.fitted`, so their marks land on it. The
// artboard's rectangle is the leaf element `suite.canvas.artboard`, as in
// CanvasViewport, for a journey that measures the document.
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
        GeometryReader { geometry in
            let board = Self.fitted(artboard, in: geometry.size, inset: SuiteSize.canvasInset)
            ZStack(alignment: .topLeading) {
                SuiteColor.canvasSurround
                Rectangle()
                    .fill(SuiteColor.artboard)
                    .frame(width: board.width, height: board.height)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                    .position(x: board.midX, y: board.midY)
                Color.clear
                    .frame(width: board.width, height: board.height)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Artboard")
                    .accessibilityIdentifier("suite.canvas.artboard")
                    .allowsHitTesting(false)
                    .position(x: board.midX, y: board.midY)
            }
        }
        .overlay(alignment: overlayAlignment) {
            overlay.padding(SuiteSpacing.l)
        }
    }
}

extension CanvasSurface {
    /// The artboard's rect in a surface of `size`: centred, at least `inset`
    /// clear of each edge, scaled by min(room.w / a.w, room.h / a.h, 1). A side
    /// of `artboard` that isn't a positive finite number counts as 1; with no
    /// room (or a size that isn't finite) the rect is empty at the centre.
    public nonisolated static func fitted(_ artboard: CGSize, in size: CGSize, inset: CGFloat) -> CGRect {
        let side = { (value: CGFloat) in value.isFinite && value > 0 ? value : 1 }
        let board = CGSize(width: side(artboard.width), height: side(artboard.height))
        let scale = CGFloat(ViewerZoom.fitScale(artboard: board, in: size, inset: inset.isFinite ? inset : 0))
        let half = { (value: CGFloat) in value.isFinite ? max(value, 0) / 2 : 0 }
        let width = board.width * scale, height = board.height * scale
        return CGRect(x: half(size.width) - width / 2, y: half(size.height) - height / 2, width: width, height: height)
    }
}

extension CanvasSurface where Overlay == EmptyView {
    public init(artboard: CGSize) {
        self.init(artboard: artboard) { EmptyView() }
    }
}
