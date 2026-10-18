// BoxMath.swift (EK-3 stub, EK-20 body): the one selection-box math. Stubs return their input.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A pending transform on a layer: scale about the box's top-left, then turn
/// clockwise about its centre, then move.
public struct LayerTransform: Hashable, Sendable {
    /// The scales (1 is unscaled), the clockwise turn in degrees and the move in document points.
    public var scaleX: Double = 1, scaleY: Double = 1, degrees: Double = 0, dx: Double = 0, dy: Double = 0

    /// A transform from its parts; every part defaults to no change.
    public init(scaleX: Double = 1, scaleY: Double = 1, degrees: Double = 0, dx: Double = 0, dy: Double = 0) {
        self.scaleX = scaleX; self.scaleY = scaleY; self.degrees = degrees; self.dx = dx; self.dy = dy
    }
}

/// Box resize, scale and rotate math by handle.
public enum BoxMath {
    /// `rect` with `handle`'s edges moved by `delta`: Shift keeps the aspect, Option resizes
    /// about the centre, the size stays at least 1, never flips. Stub: `rect` until EK-20.
    public static func resized(_ rect: Rect, _ handle: EditorHandle, by delta: Point, modifiers: EditModifiers) -> Rect {
        rect
    }

    /// Where `rect`, inside the union box `old`, lands when that box becomes
    /// `new`: several items scale as one box. Stub: `rect` unchanged until EK-20.
    public static func scaled(_ rect: Rect, from old: Rect, to new: Rect) -> Rect { rect }

    /// A rotation of `d` degrees, snapped to 15° steps with Shift. Stub: `d` until EK-20.
    public static func snappedDegrees(_ d: Double, modifiers: EditModifiers) -> Double { d }

    /// The square of side `size` each resize handle and the rotate knob
    /// occupies around `rect` (no `.inside`). Stub: empty until EK-20.
    public static func handles(of rect: Rect, size: Double) -> [EditorHandle: Rect] { [:] }
}
