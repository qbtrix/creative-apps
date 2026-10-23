// ShapeRules.swift (shape-tools SH-1 contract, SH-5 bodies): a spec's path in a box, the box a drag draws, and why a spec can't be drawn.
// Line and arrow are built here from Path's own elements because PathBuilders lacks them; they move there once a
// second caller outside the kernel needs them.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// Why a shape wasn't drawn: a spec its help refuses, or a rule not built yet.
public enum ShapeRefusal: Error, Hashable, Sendable, CustomStringConvertible {
    case invalid(String), notBuilt
    public var description: String { if case .invalid(let help) = self { help } else { "Shape tools are not built yet (shape-tools)." } }
}

public enum ShapeRules {
    /// The counts a polygon's sides and a star's points take, and the ratios a star's inner radius takes.
    public static let counts = 3...64, ratios = 0.1...1.0
    /// What a stub threw before SH-5 built the rules.
    public static let notBuilt = ShapeRefusal.notBuilt

    /// The spec's path in `box` (document space). Throws `GeometryError` from PathBuilders, or `invalid(help)`.
    public static func path(_ spec: ShapeSpec, in box: Rect) throws -> Path {
        if let help = help(spec) { throw ShapeRefusal.invalid(help) }
        switch spec.kind {
        case .rectangle: return try PathBuilders.rectangle(in: box, cornerRadius: spec.cornerRadius)
        case .ellipse: return try PathBuilders.ellipse(in: box)
        case .polygon: return try PathBuilders.polygon(in: box, sides: spec.sides)
        case .star: return try PathBuilders.star(in: box, points: spec.points, innerRatio: spec.innerRatio)
        case .line, .arrow:
            guard [box.minX, box.minY, box.maxX, box.maxY].allSatisfy(\.isFinite) else { throw GeometryError.nonFinite }
            let ordered = Rect(minX: min(box.minX, box.maxX), minY: min(box.minY, box.maxY),
                               maxX: max(box.minX, box.maxX), maxY: max(box.minY, box.maxY))
            let (a, b) = (place(spec.start, in: ordered), place(spec.end, in: ordered))
            guard spec.kind == .arrow else { return Path(polyline: [a, b], closed: false) }
            return arrow(from: a, to: b, head: spec.head)
        }
    }

    /// The box and line ends a drag draws (Shift squares it or snaps a line to 45°, Option grows it from the centre); nil if empty.
    public static func dragged(_ kind: ShapeKind, from: Point, to: Point, modifiers: EditModifiers) -> (box: Rect, spec: ShapeSpec)? {
        var (dx, dy) = (to.x - from.x, to.y - from.y)
        guard [from.x, from.y, dx, dy].allSatisfy(\.isFinite), dx != 0 || dy != 0 else { return nil }
        let line = kind == .line || kind == .arrow
        if modifiers.contains(.shift) { (dx, dy) = line ? snapped(dx, dy) : squared(dx, dy) }
        let centred = modifiers.contains(.option)
        let start = centred ? Point(x: from.x - dx, y: from.y - dy) : from
        let end = Point(x: from.x + dx, y: from.y + dy)
        guard [start.x, start.y, end.x, end.y].allSatisfy(\.isFinite), let box = Rect(enclosing: [start, end]) else { return nil }
        var spec = ShapeSpec.defaults(kind)
        if line { (spec.start, spec.end) = (unit(start, in: box), unit(end, in: box)) }
        return (box, spec)
    }

    /// Why `spec` can't be drawn ("A polygon needs 3 to 64 sides."), nil when it can. Only the kind's own options count.
    public static func help(_ spec: ShapeSpec) -> String? {
        switch spec.kind {
        case .polygon: return allowed(spec.sides) ? nil : "A polygon needs 3 to 64 sides."
        case .star:
            guard allowed(spec.points) else { return "A star needs 3 to 64 points." }
            return ratios.contains(spec.innerRatio) ? nil : "A star's inner ratio runs from 10% to 100%."
        case .rectangle: return spec.cornerRadius.isFinite && spec.cornerRadius >= 0 ? nil : "A corner radius is 0 points or more."
        case .ellipse: return nil
        case .line, .arrow:
            guard [spec.start.x, spec.start.y, spec.end.x, spec.end.y].allSatisfy(\.isFinite) else { return "A line's ends must be numbers." }
            return spec.kind == .line || (spec.head.isFinite && spec.head > 0) ? nil : "An arrow's head is longer than 0 points."
        }
    }

    /// Whether a polygon's sides or a star's points fall in `counts`.
    static func allowed(_ count: Int) -> Bool { count >= counts.lowerBound && count <= counts.upperBound }

    /// The drag with its sides equal, the larger one, keeping each side's direction.
    static func squared(_ dx: Double, _ dy: Double) -> (Double, Double) {
        let side = max(abs(dx), abs(dy))
        return (dx < 0 ? -side : side, dy < 0 ? -side : side)
    }

    /// The drag at its length, its angle rounded to the nearest 45° (tan 22.5° = √2 − 1 splits the octants).
    static func snapped(_ dx: Double, _ dy: Double) -> (Double, Double) {
        let (ax, ay) = (abs(dx), abs(dy)), length = (dx * dx + dy * dy).squareRoot(), split = 2.0.squareRoot() - 1
        if ay <= ax * split { return (dx < 0 ? -length : length, 0) }
        if ax <= ay * split { return (0, dy < 0 ? -length : length) }
        let leg = length / 2.0.squareRoot()
        return (dx < 0 ? -leg : leg, dy < 0 ? -leg : leg)
    }

    /// `p` in `box`'s unit space; 0 on an axis the box has no extent along.
    static func unit(_ p: Point, in box: Rect) -> Point {
        Point(x: box.width > 0 ? (p.x - box.minX) / box.width : 0, y: box.height > 0 ? (p.y - box.minY) / box.height : 0)
    }

    /// A unit-space point placed in `box`.
    static func place(_ u: Point, in box: Rect) -> Point { Point(x: box.minX + u.x * box.width, y: box.minY + u.y * box.height) }

    /// The shaft from `a` to the head's base, then a closed head whose tip is `b`: `head` long (at most half the
    /// line) and 0.8 of that wide. A zero-length line has no direction, so it gets no head.
    static func arrow(from a: Point, to b: Point, head: Double) -> Path {
        let (dx, dy) = (b.x - a.x, b.y - a.y), length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return Path(polyline: [a, b], closed: false) }
        let (ux, uy) = (dx / length, dy / length), long = min(head, length / 2), half = long * 0.4
        let base = Point(x: b.x - ux * long, y: b.y - uy * long)
        let corners = [Point(x: base.x - uy * half, y: base.y + ux * half), Point(x: base.x + uy * half, y: base.y - ux * half)]
        return Path(elements: [.move(to: a), .line(to: base)] + Path(polyline: [b] + corners, closed: true).elements)
    }
}
