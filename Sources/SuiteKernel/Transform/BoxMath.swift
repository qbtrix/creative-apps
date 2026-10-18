// BoxMath.swift (EK-3 shape, EK-20 body): the one selection-box math every app
// resizes, scales and rotates with. Document y grows downwards.
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
    /// `rect` with `handle`'s edges moved by `delta`. Shift (corners) keeps the aspect from
    /// the axis that changed more, relative to its size; Option mirrors the move on the
    /// opposite edge so the centre stays. Width and height stay at least 1 from the fixed
    /// edge, so the box never flips. `.inside`, `.rotate` or a non-finite delta: `rect`.
    public static func resized(_ rect: Rect, _ handle: EditorHandle, by delta: Point, modifiers: EditModifiers) -> Rect {
        guard delta.x.isFinite, delta.y.isFinite, let (h, v) = sides(of: handle) else { return rect }
        let (width, height) = (rect.width, rect.height)
        let grow = modifiers.contains(.option) ? 2.0 : 1.0
        var newWidth = width + h * delta.x * grow
        var newHeight = height + v * delta.y * grow
        if modifiers.contains(.shift), handle.isCorner, width > 0, height > 0 {
            let (scaleX, scaleY) = (newWidth / width, newHeight / height)
            let larger = abs(scaleX - 1) >= abs(scaleY - 1) ? scaleX : scaleY
            let scale = max(larger, 1 / width, 1 / height)
            (newWidth, newHeight) = (width * scale, height * scale)
        }
        (newWidth, newHeight) = (max(newWidth, 1), max(newHeight, 1))
        let fromCentre = modifiers.contains(.option)
        let (minX, maxX) = span(rect.minX, rect.maxX, newWidth, side: h, fromCentre: fromCentre)
        let (minY, maxY) = span(rect.minY, rect.maxY, newHeight, side: v, fromCentre: fromCentre)
        return Rect(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }

    /// Where `rect`, inside the union box `old`, lands when that box becomes
    /// `new`: several items scale as one box. An axis on which `old` has no size moves only.
    public static func scaled(_ rect: Rect, from old: Rect, to new: Rect) -> Rect {
        let scaleX = old.width != 0 ? new.width / old.width : 1
        let scaleY = old.height != 0 ? new.height / old.height : 1
        return Rect(
            minX: new.minX + (rect.minX - old.minX) * scaleX, minY: new.minY + (rect.minY - old.minY) * scaleY,
            maxX: new.minX + (rect.maxX - old.minX) * scaleX, maxY: new.minY + (rect.maxY - old.minY) * scaleY)
    }

    /// A rotation of `d` degrees, snapped to the nearest 15° step with Shift.
    public static func snappedDegrees(_ d: Double, modifiers: EditModifiers) -> Double {
        guard modifiers.contains(.shift), d.isFinite else { return d }
        return (d / 15).rounded() * 15
    }

    /// The square of side `size` each resize handle and the rotate knob
    /// occupies around `rect` (no `.inside`). The knob sits two sizes above the top edge.
    public static func handles(of rect: Rect, size: Double) -> [EditorHandle: Rect] {
        var squares: [EditorHandle: Rect] = [:]
        for handle in EditorHandle.allCases {
            guard let centre = HandleHit.centre(of: handle, on: rect, knobGap: 2 * size) else { continue }
            squares[handle] = Rect(
                minX: centre.x - size / 2, minY: centre.y - size / 2, maxX: centre.x + size / 2, maxY: centre.y + size / 2)
        }
        return squares
    }

    /// Which edge `handle` moves on each axis: -1 the min edge, 1 the max edge, 0 neither;
    /// nil for `.inside` and `.rotate`, which resize nothing.
    static func sides(of handle: EditorHandle) -> (Double, Double)? {
        switch handle {
        case .topLeft: (-1, -1)
        case .top: (0, -1)
        case .topRight: (1, -1)
        case .right: (1, 0)
        case .bottomRight: (1, 1)
        case .bottom: (0, 1)
        case .bottomLeft: (-1, 1)
        case .left: (-1, 0)
        case .inside, .rotate: nil
        }
    }

    /// One axis of a resized box `length` long: about the centre, from the fixed max edge
    /// (`side` -1), or from the fixed min edge.
    private static func span(_ lo: Double, _ hi: Double, _ length: Double, side: Double, fromCentre: Bool) -> (Double, Double) {
        if side == 0 { return (lo, hi) }
        if fromCentre {
            let centre = (lo + hi) / 2
            return (centre - length / 2, centre + length / 2)
        }
        return side < 0 ? (hi - length, hi) : (lo, lo + length)
    }
}
