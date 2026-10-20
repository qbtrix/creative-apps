// AnchorIndex.swift (pen-paths PN-1 stub, PN-6 body): anchors and handles on a uniform grid of `cell` document points,
// so a hover reads a few cells and a marquee reads the cells it covers, not every anchor.
/// The anchors and handles of one path, in document space, bucketed by grid cell.
public struct AnchorIndex: Sendable {
    public static let cell = 64.0
    /// A grid cell: its column and row.
    private struct Key: Hashable, Sendable { var x: Int, y: Int }
    /// One anchor or handle: its anchor, that anchor's position in path order, the handle end (nil for the anchor) and
    /// where it is.
    private struct Mark: Sendable { var ref: AnchorRef, at: Int, end: HandleEnd?, point: Point }

    /// How many anchors the index holds.
    public let count: Int
    private let anchors: [Key: [Mark]], handles: [Key: [Mark]]
    private let path: VectorPath, toDocument: Matrix

    /// The grid column or row holding coordinate `v`: `floor(v / cell)`, clamped so a huge value can't trap.
    public static func slot(_ v: Double) -> Int {
        let q = min(max(v / cell, -1e15), 1e15)
        return q.isFinite ? Int(q.rounded(.down)) : 0
    }

    /// Indexes `path`'s anchors and handles mapped through `toDocument`; a non-finite point is left out.
    public init(_ path: VectorPath, toDocument: Matrix) {
        var count = 0, anchors: [Key: [Mark]] = [:], handles: [Key: [Mark]] = [:]
        func file(_ mark: Mark, in buckets: inout [Key: [Mark]]) {
            buckets[Key(x: Self.slot(mark.point.x), y: Self.slot(mark.point.y)), default: []].append(mark)
        }
        for (c, contour) in path.contours.enumerated() {
            for (i, anchor) in contour.anchors.enumerated() {
                let point = toDocument.apply(anchor.point)
                guard point.x.isFinite, point.y.isFinite else { continue }
                let ref = AnchorRef(contour: c, index: i)
                file(Mark(ref: ref, at: count, end: nil, point: point), in: &anchors)
                func fileHandle(_ handle: Point?, _ end: HandleEnd) {
                    guard let handle else { return }
                    let h = toDocument.apply(handle)
                    if h.x.isFinite, h.y.isFinite { file(Mark(ref: ref, at: count, end: end, point: h), in: &handles) }
                }
                fileHandle(anchor.handleIn, .handleIn)
                fileHandle(anchor.handleOut, .handleOut)
                count += 1
            }
        }
        (self.count, self.anchors, self.handles, self.path, self.toDocument) = (count, anchors, handles, path, toDocument)
    }

    /// What is under `point` within `reach`, nearest first: a selected anchor's handle, then an anchor, then a segment.
    public func hit(_ point: Point, reach: Double, selected: Selection<AnchorRef>) -> PathHit? {
        guard point.x.isFinite, point.y.isFinite, reach.isFinite, reach >= 0 else { return nil }
        let area = Rect(minX: point.x - reach, minY: point.y - reach, maxX: point.x + reach, maxY: point.y + reach)
        if let mark = nearest(in: handles, area, to: point, reach: reach, where: { selected.contains($0.ref) }),
           let end = mark.end {
            return .handle(mark.ref, end)
        }
        if let mark = nearest(in: anchors, area, to: point, reach: reach, where: { _ in true }) {
            return .anchor(mark.ref)
        }
        guard reach > 0,
              let location = try? path.transformed(by: toDocument).nearest(to: point, tolerance: reach / 8),
              location.distance <= reach else { return nil }
        return .segment(location)
    }

    /// The anchors inside `rect`, edges included, sorted.
    public func inside(_ rect: Rect) -> [AnchorRef] {
        var found: [Mark] = []
        visit(anchors, rect) { mark in
            if mark.point.x >= rect.minX, mark.point.x <= rect.maxX, mark.point.y >= rect.minY, mark.point.y <= rect.maxY {
                found.append(mark)
            }
        }
        return found.sorted { $0.at < $1.at }.map(\.ref)
    }

    /// The mark in `buckets` nearest `point` within `reach` that `keep` allows; ties go to the lower ref.
    private func nearest(in buckets: [Key: [Mark]], _ area: Rect, to point: Point, reach: Double,
                         where keep: (Mark) -> Bool) -> Mark? {
        var best: (mark: Mark, distance: Double)?
        visit(buckets, area) { mark in
            let distance = ((mark.point.x - point.x) * (mark.point.x - point.x)
                + (mark.point.y - point.y) * (mark.point.y - point.y)).squareRoot()
            guard distance <= reach, keep(mark) else { return }
            if let b = best, (b.distance, b.mark.at) <= (distance, mark.at) { return }
            best = (mark, distance)
        }
        return best?.mark
    }

    /// Calls `body` with every mark in the cells `rect` covers, both edge cells included. A rect covering more cells than
    /// are filled walks the filled cells instead.
    private func visit(_ buckets: [Key: [Mark]], _ rect: Rect, _ body: (Mark) -> Void) {
        guard rect.minX <= rect.maxX, rect.minY <= rect.maxY else { return }
        let (x0, x1, y0, y1) = (Self.slot(rect.minX), Self.slot(rect.maxX), Self.slot(rect.minY), Self.slot(rect.maxY))
        let xs = x0...x1, ys = y0...y1
        if Double(x1 - x0 + 1) * Double(y1 - y0 + 1) > Double(buckets.count) {
            for (key, marks) in buckets where xs.contains(key.x) && ys.contains(key.y) { marks.forEach(body) }
            return
        }
        for y in ys { for x in xs { buckets[Key(x: x, y: y)]?.forEach(body) } }
    }
}
