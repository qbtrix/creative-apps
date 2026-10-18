// HandleHit.swift (EK-3 stub, EK-20 body): which box handle is under the pointer. Stubs never trap.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Handle hit testing for a selection box.
public enum HandleHit {
    /// The handle within `tolerance` (document points, Chebyshev) of `p` on `rect`, corners
    /// winning ties; `.inside` inside on no handle; nil outside. Stub: nil until EK-20.
    public static func handle(at p: Point, in rect: Rect, tolerance: Double) -> EditorHandle? { nil }

    /// The document tolerance for a `screen`-point one at `zoom` (screen / zoom). Stub: `screen`.
    public static func tolerance(screen: Double, zoom: Double) -> Double { screen }
}
