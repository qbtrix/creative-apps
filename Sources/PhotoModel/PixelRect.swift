// PixelRect.swift: a rectangle of whole pixels (a selection, a pending crop, a
// layer's bounds, the region a change touched), and PhotoDamage, the part of
// the canvas a change needs redrawn. A rect from two pointer points covers
// every pixel the drag touches: the low corner rounds down, the high one up.
// Invariants: width and height are never negative; an empty rect (either side
// 0) covers nothing and intersects nothing. Linux-safe.
import CoreRaster

public struct PixelRect: Sendable, Hashable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    /// Negative sizes become 0.
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = max(width, 0)
        self.height = max(height, 0)
    }

    /// The pixels between two points in either order; NaN or huge points give
    /// an empty rect.
    public init(from a: Mask.Point, to b: Mask.Point) {
        let values = [a.x, a.y, b.x, b.y]
        guard values.allSatisfy({ $0.isFinite && abs($0) < 1e9 }) else {
            self.init(x: 0, y: 0, width: 0, height: 0)
            return
        }
        let left = Int(min(a.x, b.x).rounded(.down)), top = Int(min(a.y, b.y).rounded(.down))
        let right = Int(max(a.x, b.x).rounded(.up)), bottom = Int(max(a.y, b.y).rounded(.up))
        self.init(x: left, y: top, width: right - left, height: bottom - top)
    }

    public var isEmpty: Bool { width == 0 || height == 0 }
    public var maxX: Int { x + width }
    public var maxY: Int { y + height }

    /// The pixels both cover, or nil when they don't overlap.
    public func intersection(_ other: PixelRect) -> PixelRect? {
        let left = max(x, other.x), top = max(y, other.y)
        let right = min(maxX, other.maxX), bottom = min(maxY, other.maxY)
        guard right > left, bottom > top else { return nil }
        return PixelRect(x: left, y: top, width: right - left, height: bottom - top)
    }

    /// The smallest rect covering both; an empty rect adds nothing.
    public func union(_ other: PixelRect) -> PixelRect {
        if isEmpty { return other }
        if other.isEmpty { return self }
        let left = min(x, other.x), top = min(y, other.y)
        return PixelRect(x: left, y: top, width: max(maxX, other.maxX) - left, height: max(maxY, other.maxY) - top)
    }

    /// Grown by `margin` pixels on every side.
    public func expanded(by margin: Int) -> PixelRect {
        PixelRect(x: x - margin, y: y - margin, width: width + 2 * margin, height: height + 2 * margin)
    }

    /// Moved by (`dx`, `dy`).
    public func offsetBy(_ dx: Int, _ dy: Int) -> PixelRect {
        PixelRect(x: x + dx, y: y + dy, width: width, height: height)
    }
}

/// What a change needs redrawn: nothing, one region of the canvas, or all of it.
public enum PhotoDamage: Sendable, Equatable {
    case none
    case region(PixelRect)
    case all

    /// Both changes' damage together.
    public func union(_ other: PhotoDamage) -> PhotoDamage {
        switch (self, other) {
        case (.all, _), (_, .all): .all
        case (.none, let damage), (let damage, .none): damage
        case (.region(let a), .region(let b)): .region(a.union(b))
        }
    }
}
