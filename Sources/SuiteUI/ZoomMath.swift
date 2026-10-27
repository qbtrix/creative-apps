// ZoomMath.swift: SuiteKernel's zoom model (ViewZoom.swift, the one copy) in CoreGraphics types,
// for CanvasViewport and the editor windows: the 10% to 3200% clamp, Zoom In and Zoom Out over the
// suite's stops, the fit inside the viewport's margin, and `anchoredOrigin`, the artboard origin
// that keeps the document point under the pointer there. A zoom that isn't a number is 100%, and a
// viewport with no room fits at the smallest zoom, never a division by zero. CanvasHostView's pinch
// and CanvasLayout's anchored scroll both go through `anchoredOrigin`.
// SuiteCanvasNavigating is the live CanvasNavigating (UC7) over it: the same stops, clamp and fit
// through PlaneExtent, the view-to-document point and the arrow-key pan step. Plain math, no
// SwiftUI, tested on its own (ZoomMathTests, CanvasPanTests; the model in ViewZoomTests).
import CoreGraphics
import struct SuiteKernel.ZoomSteps
import typealias SuiteKernel.Point

public enum ZoomMath {
    /// The suite's stops and range (SuiteKernel's ZoomSteps.suite).
    public static let steps = ZoomSteps.suite

    /// The zoom range, in points per document pixel: 10% to 3200%.
    public static var range: ClosedRange<Double> { steps.range }

    /// `zoom` kept inside `range`; 100% when it isn't a number.
    public static func clamped(_ zoom: Double) -> Double { steps.clamped(zoom) }

    /// The next stop above `zoom`, within `range`.
    public static func zoomedIn(from zoom: Double) -> Double { steps.zoomedIn(from: zoom) }

    /// The next stop below `zoom`, within `range`.
    public static func zoomedOut(from zoom: Double) -> Double { steps.zoomedOut(from: zoom) }

    /// The zoom that fits `document` inside `viewport` with `margin` on every side, never above 100%,
    /// within `range`.
    public static func fit(document: CGSize, in viewport: CGSize, margin: CGFloat = SuiteSpacing.xxl) -> Double {
        clamped(ViewerZoom.fitScale(artboard: document, in: viewport, inset: margin))
    }

    /// The artboard origin that keeps the document point under `pointer` under it when the zoom goes
    /// from `old` to `new`, all in view points (ZoomSteps.anchoredOrigin). TimelineZoom.anchoredOffset
    /// is the timeline's one-axis kin.
    public static func anchoredOrigin(pointer: CGPoint, origin: CGPoint, from old: Double, to new: Double) -> CGPoint {
        let p = steps.anchoredOrigin(
            pointer: Point(x: Double(pointer.x), y: Double(pointer.y)), origin: Point(x: Double(origin.x), y: Double(origin.y)),
            from: old, to: new)
        return CGPoint(x: p.x, y: p.y)
    }
}

/// The live `CanvasNavigating`: ZoomMath's stops, clamp and fit, where
/// `FakeCanvasNavigating` doubles and halves.
public struct SuiteCanvasNavigating: CanvasNavigating {
    public init() {}

    public func clamped(_ zoom: Double) -> Double { ZoomMath.clamped(zoom) }

    public func zoomedIn(from zoom: Double) -> Double { ZoomMath.zoomedIn(from: zoom) }

    public func zoomedOut(from zoom: Double) -> Double { ZoomMath.zoomedOut(from: zoom) }

    /// ZoomMath's fit: sides of 0 or less count as 1 pt (ViewerZoom.fitScale),
    /// and a viewport with no room, or one that isn't a number, gives 0.1.
    public func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double {
        ZoomMath.fit(
            document: CGSize(width: document.width, height: document.height),
            in: CGSize(width: viewport.width, height: viewport.height),
            margin: CGFloat(margin))
    }

    /// Divides by the clamped zoom, which is never below 0.1.
    public func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint {
        let z = clamped(zoom)
        return PlanePoint(x: (view.x - artboardOrigin.x) / z, y: (view.y - artboardOrigin.y) / z)
    }

    /// A tenth of the viewport on the arrow's axis, a whole one with Shift:
    /// the step CanvasLayout's `panned(from:key:page:)` scrolls by.
    public func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint {
        let page = modifiers.contains(.shift)
        let x = page ? viewport.width : viewport.width / 10
        let y = page ? viewport.height : viewport.height / 10
        switch arrow {
        case .left: return PlanePoint(x: -x, y: 0)
        case .right: return PlanePoint(x: x, y: 0)
        case .up: return PlanePoint(x: 0, y: -y)
        case .down: return PlanePoint(x: 0, y: y)
        }
    }
}
