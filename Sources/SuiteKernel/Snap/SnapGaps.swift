// SnapGaps.swift: the gap and even-spacing engine (editor-kernel EK-29 stub;
// the snapping feature's SN-3 fills the body). Given the candidate frames, it
// finds the offset that makes a moving box's gap to its neighbours match the
// spacing already between them, and the gaps to label once it has snapped.
//
// Built once per gesture: each candidate goes in every 256 pt cell its frame
// covers (a frame wider than 4,096 cells is kept aside and always read). A
// box's neighbour on a side is the nearest candidate in the cells from its
// edge out to 2,048 pt (8 cells) that overlaps it on the other axis and
// leaves a gap, so a frame that contains or overlaps the box is never one.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Gaps and spacing matches against a set of candidate frames.
public struct SnapGaps: Sendable {
    /// One grid cell: its column and row.
    struct Cell: Hashable, Sendable {
        var col: Int, row: Int
    }

    /// A neighbour: the candidate's index and the gap to it.
    struct Neighbour: Sendable {
        var index: Int, gap: Double
    }

    /// The width of one cell, in points.
    static let cellSize = 256.0
    /// How far a neighbour may be, in points (8 cells).
    static let reach = 2048.0
    /// The most cells a frame or a lookup covers before it skips the grid.
    static let maxCells = 4096
    /// How close two gaps are to count as equal, in points.
    static let equalGap = 0.5

    /// The frames the gaps are measured between.
    let candidates: [SnapCandidate]
    /// The candidates' indices by cell, and the ones too large for the grid.
    let cells: [Cell: [Int]], wide: [Int]

    /// An engine over the candidates `c`.
    public init(_ c: [SnapCandidate]) {
        candidates = c
        var grid: [Cell: [Int]] = [:], large: [Int] = []
        for (index, candidate) in c.enumerated() {
            let f = candidate.frame
            guard let cols = Self.span(f.minX, f.maxX), let rows = Self.span(f.minY, f.maxY) else { continue }
            guard Self.fits(cols, rows) else {
                large.append(index)
                continue
            }
            for col in cols { for row in rows { grid[Cell(col: col, row: row), default: []].append(index) } }
        }
        (cells, wide) = (grid, large)
    }

    /// The cell `v` falls in; nil when `v` is not finite or too large for an `Int`.
    static func cell(_ v: Double) -> Int? {
        let key = (v / cellSize).rounded(.down)
        guard key.isFinite, abs(key) < 1e15 else { return nil }
        return Int(key)
    }

    /// The cells from `a` to `b`.
    static func span(_ a: Double, _ b: Double) -> ClosedRange<Int>? {
        guard let low = cell(Swift.min(a, b)), let high = cell(Swift.max(a, b)) else { return nil }
        return low...high
    }

    /// True when `cols` by `rows` is few enough cells to walk.
    static func fits(_ cols: ClosedRange<Int>, _ rows: ClosedRange<Int>) -> Bool {
        cols.count <= maxCells && rows.count <= maxCells && cols.count * rows.count <= maxCells
    }

    /// `f`'s low and high ends on `axis`.
    static func ends(_ f: Rect, _ axis: SnapLine.Axis) -> (Double, Double) {
        axis == .x ? (f.minX, f.maxX) : (f.minY, f.maxY)
    }

    /// `f`'s low and high ends across `axis`.
    static func across(_ f: Rect, _ axis: SnapLine.Axis) -> (Double, Double) {
        ends(f, axis == .x ? .y : .x)
    }

    /// The nearest neighbour of `box` on `axis`, past its high end when
    /// `high` and past its low end otherwise; nil when none is in reach.
    func neighbour(of box: Rect, _ axis: SnapLine.Axis, high: Bool) -> Neighbour? {
        let (low, top) = Self.ends(box, axis), (side0, side1) = Self.across(box, axis)
        let edge = high ? top : low
        guard let along = Self.span(edge, high ? edge + Self.reach : edge - Self.reach),
              let side = Self.span(side0, side1) else { return nil }
        var found: Set<Int> = Set(wide)
        if Self.fits(along, side) {
            for a in along {
                for s in side { found.formUnion(cells[axis == .x ? Cell(col: a, row: s) : Cell(col: s, row: a)] ?? []) }
            }
        } else {
            found = Set(candidates.indices)
        }
        var best: Neighbour?
        for index in found.sorted() {
            let f = candidates[index].frame
            let (f0, f1) = Self.ends(f, axis), (o0, o1) = Self.across(f, axis)
            guard o0 < side1, o1 > side0 else { continue }
            let gap = high ? f0 - top : low - f1
            guard gap > 0, gap <= Self.reach else { continue }
            if let current = best, current.gap <= gap { continue }
            best = Neighbour(index: index, gap: gap)
        }
        return best
    }

    /// The gap on `axis` between `lower` and `upper` (lower first), its mark
    /// in the middle of where they overlap across it.
    static func gap(_ axis: SnapLine.Axis, _ lower: Rect, _ upper: Rect, spacing: Bool) -> SnapGap {
        let (l0, l1) = across(lower, axis), (u0, u1) = across(upper, axis)
        let mid = (Swift.max(l0, u0) + Swift.min(l1, u1)) / 2
        return SnapGap(axis: axis, from: ends(lower, axis).1, to: ends(upper, axis).0, across: mid, isSpacing: spacing)
    }

    /// The offset on `axis` that gives `box` the same spacing as its
    /// neighbours within `tolerance` (inclusive): its gap on one side equal
    /// to that neighbour's gap to the next one beyond, or its two gaps equal.
    /// The smallest wins, the negative on a tie; nil when none is that close.
    public func spacingOffset(_ axis: SnapLine.Axis, for box: Rect, tolerance: Double) -> Double? {
        let before = neighbour(of: box, axis, high: false), after = neighbour(of: box, axis, high: true)
        var options: [Double] = []
        if let b = before, let beyond = neighbour(of: candidates[b.index].frame, axis, high: false) {
            options.append(beyond.gap - b.gap)
        }
        if let a = after, let beyond = neighbour(of: candidates[a.index].frame, axis, high: true) {
            options.append(a.gap - beyond.gap)
        }
        if let b = before, let a = after { options.append((a.gap - b.gap) / 2) }
        var best: Double?
        for d in options where abs(d) <= tolerance {
            if let current = best, abs(d) > abs(current) || (abs(d) == abs(current) && d >= current) { continue }
            best = d
        }
        return best
    }

    /// The gaps around `box`, to label: on each axis, low side then high,
    /// the gap to its neighbour; a spacing hint where that gap equals (to
    /// 0.5 pt) the neighbour's gap to the next one beyond, which is then
    /// listed too, or where the box's two gaps on the axis are equal. The x
    /// gaps come first.
    public func gaps(around box: Rect) -> [SnapGap] {
        var out: [SnapGap] = []
        for axis in [SnapLine.Axis.x, .y] {
            let before = neighbour(of: box, axis, high: false), after = neighbour(of: box, axis, high: true)
            var centred = false
            if let b = before, let a = after { centred = abs(a.gap - b.gap) <= Self.equalGap }
            for (high, side) in [(false, before), (true, after)] {
                guard let side else { continue }
                let near = candidates[side.index].frame
                let beyond = neighbour(of: near, axis, high: high)
                let matches = beyond.map { abs($0.gap - side.gap) <= Self.equalGap } ?? false
                let spacing = centred || matches
                out.append(high ? Self.gap(axis, box, near, spacing: spacing) : Self.gap(axis, near, box, spacing: spacing))
                guard matches, let beyond else { continue }
                let far = candidates[beyond.index].frame
                out.append(high ? Self.gap(axis, near, far, spacing: true) : Self.gap(axis, far, near, spacing: true))
            }
        }
        return out
    }
}
