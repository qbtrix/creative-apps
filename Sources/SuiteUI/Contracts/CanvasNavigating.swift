// CanvasNavigating.swift: UC7 (SJ9, SP2), the canvas's zoom stops, clamp, fit,
// view-to-document mapping and arrow-key pan step, and FakeCanvasNavigating,
// which doubles and halves on purpose (the live rule steps through
// ViewerZoom's stops). Foundation only; verbatim from
// docs/blueprints/suiteui/contracts/Contracts.swift. PlaneExtent, PlanePoint,
// GridArrow and KeyModifiers live in ContractTypes.swift. The live rule is
// canvas-marks CM-3's SuiteCanvasNavigating, which wraps ZoomMath (zoom, fit)
// and CanvasLayout's pan step rather than repeating them.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol CanvasNavigating: Sendable {
    /// 0.1...32 (10 % to 3200 %); a zoom that isn't a number is 1.
    func clamped(_ zoom: Double) -> Double
    func zoomedIn(from zoom: Double) -> Double
    func zoomedOut(from zoom: Double) -> Double
    /// The zoom that fits `document` inside `viewport` less `margin` on every side, never above 1 (100 %);
    /// a side that is 0 or negative counts as 1 pt, so a 0 × 0 document fits at 100 %; a viewport with no
    /// room gives the smallest zoom. Never a division by zero.
    func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double
    /// A view point (in the canvas's content, scrolled) to document pixels.
    func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint
    /// How far an arrow key pans: a tenth of the viewport, ⇧ a whole one.
    func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint
}

/// Doubles and halves instead of the live zoom stops.
public struct FakeCanvasNavigating: CanvasNavigating {
    public init() {}
    public func clamped(_ zoom: Double) -> Double { zoom.isFinite ? min(max(zoom, 0.1), 32) : 1 }
    public func zoomedIn(from zoom: Double) -> Double { clamped(zoom * 2) }
    public func zoomedOut(from zoom: Double) -> Double { clamped(zoom / 2) }
    public func fit(document: PlaneExtent, in viewport: PlaneExtent, margin: Double) -> Double {
        let w = viewport.width - 2 * margin, h = viewport.height - 2 * margin
        guard w > 0, h > 0 else { return 0.1 }
        return clamped(min(w / max(document.width, 1), h / max(document.height, 1), 1))
    }
    public func documentPoint(_ view: PlanePoint, artboardOrigin: PlanePoint, zoom: Double) -> PlanePoint {
        let z = clamped(zoom)
        return PlanePoint(x: (view.x - artboardOrigin.x) / z, y: (view.y - artboardOrigin.y) / z)
    }
    public func panStep(_ arrow: GridArrow, viewport: PlaneExtent, modifiers: KeyModifiers) -> PlanePoint {
        let f = modifiers.contains(.shift) ? 1.0 : 0.1
        switch arrow {
        case .left: return PlanePoint(x: -viewport.width * f, y: 0)
        case .right: return PlanePoint(x: viewport.width * f, y: 0)
        case .up: return PlanePoint(x: 0, y: -viewport.height * f)
        case .down: return PlanePoint(x: 0, y: viewport.height * f)
        }
    }
}
