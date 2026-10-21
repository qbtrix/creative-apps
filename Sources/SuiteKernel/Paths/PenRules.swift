// PenRules.swift (pen-paths PN-1 stubs, PN-5 bodies): Flare's Pen rules in the kernel, moved from `LiveShapes.pen` and
// `FlareWorkspace.finishPathHelp` with their numbers. A press within `anchorTolerance` on screen of the last anchor adds
// nothing; a drag makes the anchor symmetric, its in-handle the out-handle mirrored through it; three or more distinct
// anchors close at `closeDistance` of the first, inclusive, and closing appends nothing (the first anchor is the end).
import FlareCore

public enum PenRules {
    /// View points: how near the first anchor a press closes, and how near the last one it adds nothing.
    public static let closeDistance = 4.0, anchorTolerance = 1.0
    public static let degenerate = "Click at least two separate places to draw a path."
    public static let notBuilt = CatalogError.notBuilt(id: "path", feature: "pen-paths PN-7")

    /// The draft after a press at `point`, with a drag's `handleOut` (nil, or the point itself, for a click). A closed or
    /// missing draft starts a new one; a non-finite point or `handleOut` changes nothing.
    public static func add(_ point: Point, handleOut: Point?, to draft: PenDraft?, scale: Double) -> PenDraft {
        var draft = draft.flatMap { $0.contour.closed ? nil : $0 } ?? PenDraft(contour: VectorContour(anchors: [], closed: false), scale: scale)
        draft.scale = scale
        guard point.isFinite, handleOut?.isFinite ?? true else { return draft }
        if let last = draft.contour.anchors.last, near(last.point, point, scaled(anchorTolerance, scale)) { return draft }
        let out = handleOut.flatMap { $0 != point ? $0 : nil }
        draft.contour.anchors.append(VectorAnchor(point: point, handleIn: out.map { mirror($0, through: point) }, handleOut: out,
                                                  kind: out == nil ? .corner : .symmetric))
        return draft
    }

    /// Whether a press at `point` closes `draft`: three or more anchors `anchorTolerance` apart and `point` within
    /// `closeDistance` of the first, both on screen at the draft's scale. A press near the last anchor is ignored first.
    public static func closes(_ point: Point, _ draft: PenDraft) -> Bool {
        let points = draft.contour.anchors.map(\.point), tolerance = scaled(anchorTolerance, draft.scale)
        guard !draft.contour.closed, let first = points.first, let last = points.last, !near(last, point, tolerance),
              distinct(points, tolerance) >= 3
        else { return false }
        return near(first, point, scaled(closeDistance, draft.scale), inclusive: true)
    }

    /// The draft closed onto its first anchor, no anchor added.
    public static func closed(_ draft: PenDraft) -> PenDraft {
        var draft = draft
        draft.contour.closed = true
        return draft
    }

    /// Why Finish can't end the draft (Flare's two reasons), nil when it can.
    public static func finishHelp(_ draft: PenDraft?) -> String? {
        guard let draft, !draft.contour.closed, !draft.contour.anchors.isEmpty else { return "Click with the Pen to start a path." }
        guard draft.contour.anchors.count >= 2 else { return "Click a second point to finish the path." }
        return nil
    }

    /// The draft as a path, throwing `degenerate` when its extent is under `anchorTolerance` on screen.
    public static func path(_ draft: PenDraft) throws -> VectorPath {
        guard spans(draft.contour.anchors.map(\.point), scaled(anchorTolerance, draft.scale)) else {
            throw CatalogError.unavailable(id: "path", why: degenerate)
        }
        return VectorPath(contours: [draft.contour])
    }

    static func mirror(_ p: Point, through a: Point) -> Point { Point(x: 2 * a.x - p.x, y: 2 * a.y - p.y) }
    /// `points` view points in document points at `scale`; +infinity for a degenerate scale.
    static func scaled(_ points: Double, _ scale: Double) -> Double {
        guard scale > 0 else { return .infinity }  // also NaN
        let value = points / scale
        return value.isFinite ? value : .infinity
    }
    static func near(_ a: Point, _ b: Point, _ tolerance: Double, inclusive: Bool = false) -> Bool {
        let d = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y), t = tolerance * tolerance
        return inclusive ? d <= t : d < t
    }
    static func distinct(_ points: [Point], _ tolerance: Double) -> Int {
        points.enumerated().filter { p in !points.prefix(p.offset).contains { near($0, p.element, tolerance) } }.count
    }
    static func spans(_ points: [Point], _ tolerance: Double) -> Bool {
        let xs = points.map(\.x), ys = points.map(\.y)
        guard (xs + ys).allSatisfy(\.isFinite), let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max()
        else { return false }
        return x1 - x0 >= tolerance || y1 - y0 >= tolerance
    }
}
