// CanvasSurface.swift: the content layer of a canvas app: a neutral surround
// with the artboard centered and scaled to fit, plus an optional floating
// overlay (a ToolbarGroup palette or a GlassPanel) pinned to one edge. The
// surround and artboard are flat; only the overlay may be glass. The artboard
// sits at `fitted(_:in:inset:)` (ViewerZoom.fitScale's scale, centered) and is
// the element `suite.canvas.artboard`, the frame the UI journeys read.
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

    /// The artboard's rect in a surface of `size`: scaled to fit inside
    /// `inset` on every side, never above 1, centered. Non-positive artboard
    /// sides count as 1 point; a surface with no room gives a zero-size rect
    /// at its center. The scale is ViewerZoom.fitScale's, so the viewer's zoom
    /// readout and this rect agree.
    public static func fitted(_ artboard: CGSize, in size: CGSize, inset: CGFloat = SuiteSize.canvasInset) -> CGRect {
        let scale = CGFloat(ViewerZoom.fitScale(artboard: artboard, in: size, inset: inset))
        let width = max(artboard.width, 1) * scale
        let height = max(artboard.height, 1) * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    public var body: some View {
        ZStack {
            SuiteColor.canvasSurround
            GeometryReader { proxy in
                let rect = Self.fitted(artboard, in: proxy.size)
                Rectangle()
                    .fill(SuiteColor.artboard)
                    .frame(width: rect.width, height: rect.height)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Artboard")
                    .accessibilityIdentifier("suite.canvas.artboard")
                    .position(x: rect.midX, y: rect.midY)
            }
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
