// AnchorEdit.swift (pen-paths PN-1 stubs, PN-5 bodies): point edits on a path in its own space; insert, remove (high
// index to low) and convert go through FlareCore's `inserting(at:)`, `removingAnchor` and `converting`. A path keeps no
// kinds: its `contours` measure them from the handles, so an edit reads kinds as measured.
import FlareCore

public enum AnchorEdit {
    /// The path with each of `anchors` and its handles shifted by (dx, dy); refs past the path are ignored, and a
    /// non-finite shift changes nothing.
    public static func moved(_ path: VectorPath, _ anchors: Set<AnchorRef>, dx: Double, dy: Double) -> VectorPath {
        guard dx.isFinite, dy.isFinite else { return path }
        func shift(_ p: Point) -> Point { Point(x: p.x + dx, y: p.y + dy) }
        return edit(path, anchors) { a in
            a.point = shift(a.point)
            a.handleIn = a.handleIn.map(shift)
            a.handleOut = a.handleOut.map(shift)
        }
    }

    /// The path with `ref`'s handle at `end` moved `to`. A smooth anchor's other handle turns opposite at its own length,
    /// a symmetric one's at the new length; `breaking` leaves the other handle put and makes the anchor a corner. A
    /// non-finite `to` changes nothing.
    public static func movingHandle(_ path: VectorPath, _ ref: AnchorRef, _ end: HandleEnd, to: Point, breaking: Bool) -> VectorPath {
        guard to.isFinite else { return path }
        return edit(path, [ref]) { a in
            let other = end == .handleIn ? a.handleOut : a.handleIn
            var partner = other
            let ux = a.point.x - to.x, uy = a.point.y - to.y, length = (ux * ux + uy * uy).squareRoot()
            if breaking {
                a.kind = .corner
            } else if a.kind != .corner, let other, length > 0, length.isFinite {
                let ox = other.x - a.point.x, oy = other.y - a.point.y
                let keep = a.kind == .symmetric ? length : (ox * ox + oy * oy).squareRoot()
                partner = Point(x: a.point.x + ux / length * keep, y: a.point.y + uy / length * keep)
            }
            if end == .handleIn { (a.handleIn, a.handleOut) = (to, partner) } else { (a.handleOut, a.handleIn) = (to, partner) }
        }
    }

    /// The path with a new anchor at `location` (the drawn shape unchanged) and that anchor's ref, found by walking the
    /// elements to `location.element` the way `contours` reads them: a move, or a segment after a close, starts a contour.
    public static func inserting(_ path: VectorPath, at location: FlareCore.PathLocation) throws -> (path: VectorPath, ref: AnchorRef) {
        let inserted = try path.inserting(at: location)
        var contour = -1, index = 0, closed = false
        for (i, element) in path.elements.enumerated() where i <= location.element {
            switch element {
            case .move: (contour, index, closed) = (contour + 1, 0, false)
            case .close where i < location.element: closed = true
            default:
                if contour < 0 { (contour, index) = (0, 0); continue }  // no move first: this end is the first anchor
                if closed { (contour, index, closed) = (contour + 1, 0, false) }
                index += 1
            }
        }
        return (inserted, AnchorRef(contour: max(contour, 0), index: index))
    }

    /// The path without `anchors`, removed high index to low so each ref still names its anchor; a contour left empty goes.
    public static func removing(_ path: VectorPath, _ anchors: Set<AnchorRef>) throws -> VectorPath {
        try anchors.sorted(by: >).reduce(path) { try $0.removingAnchor(contour: $1.contour, index: $1.index) }
    }

    /// The path with each of `anchors` made `kind` by FlareCore's `converting`.
    public static func converting(_ path: VectorPath, _ anchors: Set<AnchorRef>, to kind: AnchorKind) throws -> VectorPath {
        try anchors.sorted().reduce(path) { try $0.converting(contour: $1.contour, index: $1.index, to: kind) }
    }

    /// `point` snapped to `lines` within `tolerance`. The caller builds `lines` once per gesture from the anchors of `path`
    /// not in `moving` (zero-size candidates) plus its frame candidates, so the moving anchors never snap to themselves.
    public static func snapped(_ point: Point, moving: Set<AnchorRef>, in path: VectorPath, lines: SnapLines, tolerance: Double) -> Point {
        Point(x: point.x + (lines.offset(.x, for: [point.x], tolerance: tolerance) ?? 0),
              y: point.y + (lines.offset(.y, for: [point.y], tolerance: tolerance) ?? 0))
    }

    /// The path with `change` applied to each anchor in `refs` that it has.
    static func edit(_ path: VectorPath, _ refs: Set<AnchorRef>, _ change: (inout VectorAnchor) -> Void) -> VectorPath {
        var contours = path.contours
        for ref in refs where contours.indices.contains(ref.contour) && contours[ref.contour].anchors.indices.contains(ref.index) {
            change(&contours[ref.contour].anchors[ref.index])
        }
        return VectorPath(contours: contours)
    }
}
