// AnchorIndex.swift (pen-paths PN-1 stub, PN-6 body): anchors and handles on a uniform grid of `cell` document points,
// so a hover reads a few cells and a marquee reads the cells it covers, not every anchor. Each drawing segment is filed
// in the cells its control box covers, so a segment hover searches only the segments near it.
import FlareCore
/// The anchors and handles of one path, in document space, bucketed by grid cell.
public struct AnchorIndex: Sendable {
    public static let cell = 64.0
    /// A grid cell: its column and row.
    private struct Key: Hashable, Sendable { var x: Int, y: Int }
    /// One anchor or handle: its anchor, that anchor's position in path order, the handle end (nil for the anchor) and
    /// where it is.
    private struct Mark: Sendable { var ref: AnchorRef, at: Int, end: HandleEnd?, point: Point }
    /// One drawing segment in document space: its element index in the path, its start and the element from there.
    private struct Piece: Sendable { var element: Int, from: Point, to: PathElement }
    /// Most cells one segment is filed in; a wider one (or one with a non-finite point) is searched on every hover.
    static let maxCellsPerSegment = 64

    /// How many anchors the index holds.
    public let count: Int
    private let anchors: [Key: [Mark]], handles: [Key: [Mark]]
    private let pieces: [Piece], segments: [Key: [Int]]
    /// The segments every hover searches (see `maxCellsPerSegment`), as indexes into `pieces`.
    let wide: [Int]

    /// The grid column or row holding coordinate `v`: `floor(v / cell)`, clamped so a huge value can't trap.
    static func slot(_ v: Double) -> Int {
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
        (self.count, self.anchors, self.handles) = (count, anchors, handles)
        (pieces, segments, wide) = Self.fileSegments(path.transformed(by: toDocument))
    }

    /// The drawing segments of `doc` (a close becomes a line back to its start), each filed in the cells of its
    /// control box, or in `wide` past `maxCellsPerSegment` cells or with a non-finite point.
    private static func fileSegments(_ doc: VectorPath) -> ([Piece], [Key: [Int]], [Int]) {
        var pieces: [Piece] = [], cells: [Key: [Int]] = [:], wide: [Int] = []
        pieces.reserveCapacity(doc.elements.count)
        var last: Point?, start: Point?
        let elements = doc.elements
        for i in elements.indices {
            var from = last ?? start, to = elements[i], c1: Point, c2: Point, end: Point, closing = false
            switch to {
            case .move(let p): last = p; start = p; continue
            case .close:
                guard let s = start else { last = nil; continue }
                from = last; to = .line(to: s); c1 = s; c2 = s; end = s; last = nil; closing = true
            case .line(let p): c1 = p; c2 = p; end = p
            case .quad(let c, let p): c1 = c; c2 = c; end = p
            case .cubic(let a, let b, let p): c1 = a; c2 = b; end = p
            }
            if !closing {
                if from == nil { start = end }
                last = end
            }
            guard let from else { continue }
            let n = pieces.count
            pieces.append(Piece(element: i, from: from, to: to))
            guard from.isFinite, c1.isFinite, c2.isFinite, end.isFinite else { wide.append(n); continue }
            let (cx, cy) = (slot(min(min(from.x, c1.x), min(c2.x, end.x)))...slot(max(max(from.x, c1.x), max(c2.x, end.x))),
                            slot(min(min(from.y, c1.y), min(c2.y, end.y)))...slot(max(max(from.y, c1.y), max(c2.y, end.y))))
            guard Double(cx.count) * Double(cy.count) <= Double(maxCellsPerSegment) else { wide.append(n); continue }
            for y in cy { for x in cx { cells[Key(x: x, y: y), default: []].append(n) } }
        }
        return (pieces, cells, wide)
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
        guard reach > 0 else { return nil }
        // Every segment within reach has its control box in a cell `area` covers. In element order, so ties go to the
        // earlier element as in a search of the whole path.
        var near = Set(wide)
        visit(segments, area) { near.insert($0) }
        let found = near.sorted().filter(pieces.indices.contains).map { pieces[$0] }
        guard !found.isEmpty else { return nil }
        let local = VectorPath(elements: found.flatMap { [.move(to: $0.from), $0.to] })
        guard var location = try? local.nearest(to: point, tolerance: reach / 8), location.distance <= reach,
              found.indices.contains(location.element / 2) else { return nil }
        location.element = found[location.element / 2].element
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

    /// The mark in `buckets` nearest `point` within `reach` that `keep` allows; ties go to the earlier anchor, then to
    /// the anchor itself, then handleIn before handleOut.
    private func nearest(in buckets: [Key: [Mark]], _ area: Rect, to point: Point, reach: Double,
                         where keep: (Mark) -> Bool) -> Mark? {
        var best: (mark: Mark, distance: Double)?
        visit(buckets, area) { mark in
            let distance = ((mark.point.x - point.x) * (mark.point.x - point.x)
                + (mark.point.y - point.y) * (mark.point.y - point.y)).squareRoot()
            guard distance <= reach, keep(mark) else { return }
            if let b = best, (b.distance, b.mark.at, Self.rank(b.mark.end)) <= (distance, mark.at, Self.rank(mark.end)) { return }
            best = (mark, distance)
        }
        return best?.mark
    }

    private static func rank(_ end: HandleEnd?) -> Int { end == .handleOut ? 2 : end == .handleIn ? 1 : 0 }

    /// Calls `body` with every item in the cells `rect` covers, both edge cells included. A rect covering more cells than
    /// are filled walks the filled cells instead.
    private func visit<T>(_ buckets: [Key: [T]], _ rect: Rect, _ body: (T) -> Void) {
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
