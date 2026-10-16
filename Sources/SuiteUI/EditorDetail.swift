// EditorDetail.swift: the detail column of a canvas editor inside a
// SuiteWindow (docs/design.md, Editor shell). From the top: the canvas (a
// CanvasViewport, rulers included) filling the column, with the floating tool
// palette (a `.floating` ToolbarGroup) over its leading edge, then a hairline
// and the status line (a ViewerStatusBar). The palette sits `ruler + l` from
// the leading edge and is centred in the area inside the rulers, so it never
// covers a ruler. Content, not chrome: flat on the canvas surround, no glass;
// the palette brings its one capsule. The canvas region carries the
// accessibility identifier `suite.viewport` and the status line
// `suite.status`. EditorDetailLayout is the palette and fit math, plain and
// tested on its own (EditorDetailLayoutTests): a host fits its artboard with
// `fitScale(artboard:)` so a fitted page's handles stay clear of the palette,
// and EditorDetail hands the same fit to CanvasViewport's Command-0 through
// `\.canvasFitScale` (read through `ZoomMath.fit(document:in:using:)`).
// Owns no model state; it only measures its palette.
import SwiftUI

public struct EditorDetail<Canvas: View, Palette: View, Status: View>: View {
    private let canvas: Canvas
    private let palette: Palette
    private let status: Status
    /// The palette's measured height, from which its tool count follows.
    @State private var paletteHeight: CGFloat = 0

    public init(
        @ViewBuilder canvas: () -> Canvas, @ViewBuilder palette: () -> Palette,
        @ViewBuilder status: () -> Status
    ) {
        self.canvas = canvas()
        self.palette = palette()
        self.status = status()
    }

    public var body: some View {
        let toolCount = EditorDetailLayout.toolCount(paletteHeight: paletteHeight)
        let fit: @Sendable (CGSize, CGSize) -> Double = { viewport, artboard in
            EditorDetailLayout(viewport: viewport, toolCount: toolCount).fitScale(artboard: artboard)
        }
        VStack(spacing: 0) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.canvasFitScale, fit)
                .overlay(alignment: .leading) {
                    palette
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { paletteHeight = $0 }
                        // Never over the rulers: past the vertical one, centred below the horizontal one.
                        .padding(.leading, SuiteSize.ruler + SuiteSpacing.l)
                        .padding(.top, SuiteSize.ruler)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.viewport")
            Divider()
            status
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.status")
        }
        .background(SuiteColor.canvasSurround)
    }
}

/// Where EditorDetail's floating palette sits over the canvas, and the zoom
/// that fits an artboard clear of it.
public struct EditorDetailLayout: Equatable, Sendable {
    /// The area inside the rulers, as CanvasViewport reports it through `onSize`.
    public let viewport: CGSize
    /// The palette's tool count; never negative.
    public let toolCount: Int

    /// `viewport` is what CanvasViewport reports through `onSize`: the area inside the rulers.
    public init(viewport: CGSize, toolCount: Int) {
        self.viewport = viewport
        self.toolCount = max(toolCount, 0)
    }

    /// A vertical floating palette of `toolCount` buttons: one button wide and
    /// `toolCount` high, with the capsule's `xs` padding on every side.
    public static func paletteSize(toolCount: Int) -> CGSize {
        let inset = 2 * SuiteSpacing.xs
        return CGSize(
            width: SuiteSize.toolButton + inset,
            height: CGFloat(max(toolCount, 0)) * SuiteSize.toolButton + inset)
    }

    /// The tool count of a vertical floating palette `paletteHeight` tall; 0 for no palette.
    public static func toolCount(paletteHeight: CGFloat) -> Int {
        let buttons = (paletteHeight - 2 * SuiteSpacing.xs) / SuiteSize.toolButton
        guard buttons.isFinite, buttons > 0 else { return 0 }
        return Int(buttons.rounded())
    }

    /// The palette in viewport coordinates: `l` from the leading ruler, centred
    /// vertically, never above the top ruler.
    public var paletteFrame: CGRect {
        let size = Self.paletteSize(toolCount: toolCount)
        let height = viewport.height.isFinite ? viewport.height : 0
        return CGRect(origin: CGPoint(x: SuiteSpacing.l, y: max((height - size.height) / 2, 0)), size: size)
    }

    /// The room a fitted artboard keeps on its leading and trailing sides: the
    /// palette's inset and width, half a handle's hit and `xs`. The rulers are
    /// already outside `viewport`.
    public var clearance: CGFloat {
        SuiteSpacing.l + Self.paletteSize(toolCount: toolCount).width + SuiteSize.anchorHit / 2 + SuiteSpacing.xs
    }

    /// The zoom at which `artboard` (document pixels) sits centred with
    /// `clearance` on either side and `xxl` above and below, never below the
    /// smallest zoom stop. Non-positive artboard sides count as one pixel; a
    /// viewport with no room, or one that isn't finite, gives the smallest stop.
    /// Hosts call this instead of ViewerZoom.fitScale.
    public func fitScale(artboard: CGSize) -> Double {
        let smallest = ViewerZoom.stops.first ?? 0.05
        let width = artboard.width.isFinite && artboard.width > 0 ? artboard.width : 1
        let height = artboard.height.isFinite && artboard.height > 0 ? artboard.height : 1
        let horizontal = (viewport.width - 2 * clearance) / width
        let vertical = (viewport.height - 2 * SuiteSpacing.xxl) / height
        let scale = Double(min(horizontal, vertical))
        guard scale.isFinite else { return smallest }
        return max(scale, smallest)
    }
}

extension ZoomMath {
    /// Command-0's zoom in a CanvasViewport: the host's `fitScale` (the
    /// environment's `canvasFitScale`) when it sets one, else ZoomMath's fit.
    public static func fit(
        document: CGSize, in viewport: CGSize, using fitScale: (@Sendable (CGSize, CGSize) -> Double)?
    ) -> Double {
        guard let fitScale else { return fit(document: document, in: viewport) }
        return fitScale(viewport, document)
    }
}

extension EnvironmentValues {
    /// The fit Command-0 asks for in a CanvasViewport: given the viewport (the
    /// area inside the rulers) and the document size, the zoom. EditorDetail
    /// sets it from EditorDetailLayout; nil keeps ZoomMath's fit. A plain key
    /// rather than `@Entry`, as in Glass.swift.
    public var canvasFitScale: (@Sendable (CGSize, CGSize) -> Double)? {
        get { self[CanvasFitScaleKey.self] }
        set { self[CanvasFitScaleKey.self] = newValue }
    }
}

private struct CanvasFitScaleKey: EnvironmentKey {
    static let defaultValue: (@Sendable (CGSize, CGSize) -> Double)? = nil
}
