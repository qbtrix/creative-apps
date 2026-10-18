// DesignWholePoints.swift: whole points for the canvas's gestures (canvas-basics
// CB-2). A draw, a move (one layer or several) and a resize land on whole
// points at any zoom, so the inspector reads 820 and not 820.3. A move rounds
// the moved layer's top-left (or the selection box's) and shifts its children
// by the same amount, so they keep their offsets. Typed values and nudges keep
// their fractions. Linux-safe.

extension DesignPoint {
    /// Both coordinates rounded to the nearest whole point (.5 rounds up); non-finite stays as is.
    public var wholePoints: DesignPoint { DesignPoint(x: whole(x), y: whole(y)) }
}

extension DesignRect {
    /// The rectangle with each edge on a whole point, both sides at least 1.
    public var wholePoints: DesignRect {
        let (left, top) = (whole(x), whole(y))
        return DesignRect(x: left, y: top, width: Swift.max(whole(maxX) - left, 1), height: Swift.max(whole(maxY) - top, 1))
    }

    /// `delta` changed so that this rectangle, moved by it, has its top-left on a whole point.
    func wholeDelta(_ delta: DesignPoint) -> DesignPoint {
        let to = DesignPoint(x: x + delta.x, y: y + delta.y).wholePoints
        return DesignPoint(x: to.x - x, y: to.y - y)
    }
}

/// `value` rounded to the nearest whole number, .5 up (-2.5 to -2); non-finite as is.
private func whole(_ value: Double) -> Double {
    guard value.isFinite else { return value }
    let nearest = value.rounded()
    return value - nearest == 0.5 ? nearest + 1 : nearest
}
