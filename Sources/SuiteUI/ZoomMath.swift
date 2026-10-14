// ZoomMath.swift: the zoom CanvasViewport applies itself (pinch, Command-plus,
// Command-minus, Command-0), clamped to 10% to 3200%. Zoom In and Zoom Out
// step through ViewerZoom's stops; Fit is ViewerZoom's fit scale inside the
// viewport's margin. A zoom that isn't a number is 100%, and a viewport with
// no room fits at the smallest zoom, never a division by zero. Plain math, no
// SwiftUI, tested on its own (ZoomMathTests).
import CoreGraphics

public enum ZoomMath {
    /// The zoom range, in points per document pixel: 10% to 3200%.
    public static let range: ClosedRange<Double> = 0.1...32

    /// `zoom` kept inside `range`; 100% when it isn't a number.
    public static func clamped(_ zoom: Double) -> Double {
        zoom.isNaN ? 1 : min(max(zoom, range.lowerBound), range.upperBound)
    }

    /// The next stop above `zoom`, within `range`.
    public static func zoomedIn(from zoom: Double) -> Double {
        clamped(ViewerZoom.zoomedIn(from: zoom))
    }

    /// The next stop below `zoom`, within `range`.
    public static func zoomedOut(from zoom: Double) -> Double {
        clamped(ViewerZoom.zoomedOut(from: zoom))
    }

    /// The zoom that fits `document` inside `viewport` with `margin` on every
    /// side, never above 100%, within `range`.
    public static func fit(document: CGSize, in viewport: CGSize, margin: CGFloat = SuiteSpacing.xxl) -> Double {
        clamped(ViewerZoom.fitScale(artboard: document, in: viewport, inset: margin))
    }
}
