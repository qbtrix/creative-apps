// FlarePen+Kernel.swift (pen-paths FP-1, FP-5): the Pen on SuiteKernel's PenRules. A pen ShapeDraft stores a PenDraft
// and draws it as the shape (with a trailing move for a lone anchor's out-handle); LiveShapes and FakeShapes both draft
// and check a commit through here. Return finishes an open path (`finishPath`), and `addPath` adds one "Add Path".
import FlareCore
import SuiteKernel

extension ShapeDraft {
    /// The pen draft as one contour at the stage scale; nil for another tool. Setting it redraws the shape; setting nil
    /// leaves the draft alone.
    public var pen: PenDraft? {
        get { tool == .pen ? penStore : nil }
        set {
            guard let newValue else { return }
            penStore = newValue
            var path = VectorPath(contours: [newValue.contour])
            if newValue.contour.anchors.count == 1, let handle = newValue.contour.anchors.first?.handleOut {
                path.elements.append(.move(to: handle))
            }
            shape = Self.penShape(points: anchors, closed: isClosed, path: path)
        }
    }

    /// `previous` after a pen press at `start` dragged to `end`: it closes on the first anchor when PenRules says so,
    /// else adds an anchor (smooth for a drag). A closed or non-pen `previous` starts a new draft at its stage scale.
    static func penDraft(at start: Point, to end: Point, previous: ShapeDraft?) -> ShapeDraft {
        let scale = previous?.stageScale ?? 1
        var base = previous?.pen.flatMap { $0.contour.closed ? nil : $0 }
        base?.scale = scale
        var draft = ShapeDraft(tool: .pen, shape: FlareShape(points: []), stageScale: scale)
        if let base, PenRules.closes(start, base) {
            draft.pen = PenRules.closed(base)
        } else {
            draft.pen = PenRules.add(start, handleOut: end, to: base, scale: scale)
        }
        return draft
    }

    /// Throws `CommandError.invalidDocument(PenRules.degenerate)` for a pen draft PenRules can't make a path of.
    func checkPenPath() throws {
        guard let pen else { return }
        do { _ = try PenRules.path(pen) } catch { throw CommandError.invalidDocument(PenRules.degenerate) }
    }

    /// The contour `init` stores: `shape`'s first contour when it runs through `anchors` (a lone anchor's trailing move
    /// as its out-handle), else corner anchors. A smooth anchor with only an in-handle gets it mirrored out.
    static func contour(of shape: FlareShape, anchors: [Point], smooth: Set<Int>, closed: Bool) -> VectorContour {
        let contours = shape.path?.contours ?? []
        var contour = contours.first.flatMap { $0.anchors.map(\.point) == anchors ? $0 : nil }
            ?? VectorContour(anchors: anchors.map { VectorAnchor(point: $0) }, closed: closed)
        if anchors.count == 1, contours.count == 2, let handle = contours.last?.anchors.first?.point {
            contour.anchors[0].handleOut = handle
        }
        for index in contour.anchors.indices where smooth.contains(index) {
            let anchor = contour.anchors[index]
            if anchor.handleOut == nil, let handle = anchor.handleIn {
                // TODO(#4012): call PenRules.mirror(_:through:) once SuiteKernel makes it public; it is internal today.
                contour.anchors[index].handleOut = Point(x: 2 * anchor.point.x - handle.x, y: 2 * anchor.point.y - handle.y)
            }
        }
        contour.closed = closed
        return contour
    }

    /// A pen path's shape as LiveShapes draws it: clear fill, the default stroke.
    static func penShape(points: [Point], closed: Bool, path: VectorPath) -> FlareShape {
        FlareShape(points: points, closed: closed, fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), path: path, stroke: Stroke())
    }
}

extension FlareWorkspace {
    /// Anchors an open pen draft needs before Finish can end it.
    public static let minimumFinishAnchors = 2

    /// Why Finish Path can't run, or nil when an open pen draft has `minimumFinishAnchors` anchors.
    public var finishPathHelp: String? {
        guard let draft, draft.tool == .pen, !draft.isClosed else { return "Click with the Pen to start a path." }
        guard draft.anchors.count >= Self.minimumFinishAnchors else { return "Click a second point to finish the path." }
        return lockedHelp(.pen)
    }

    /// Commits the open pen draft as it stands, one "Add Path"; a refused commit keeps the draft.
    public mutating func finishPath() {
        guard let pending = draft, pending.tool == .pen, !pending.isClosed,
              pending.anchors.count >= Self.minimumFinishAnchors else { return }
        if let reason = lockedHelp(.pen) { return refuse(.refused(reason)) }
        cancelDrag()
        commit(pending)
        if layerError != nil { draft = pending }
    }

    /// `draft` when it is a pen draft. Setting nil drops a pen draft; a value starts or replaces one.
    public var penDraft: PenDraft? {
        get { draft?.pen }
        set {
            guard let newValue else {
                if draft?.tool == .pen { draft = nil }
                return
            }
            var pen = draft.flatMap { $0.tool == .pen ? $0 : nil } ?? ShapeDraft(tool: .pen, shape: FlareShape(points: []))
            pen.pen = newValue
            draft = pen
        }
    }

    /// Commits `path` as one "Add Path" (the service's name) and returns the new layer's id; throws when none was added.
    public mutating func addPath(_ path: VectorPath, name: String) throws -> String {
        let points = path.contours.flatMap { $0.anchors.map(\.point) }
        let closed = path.contours.first?.closed ?? false
        let draft = ShapeDraft(tool: .pen, shape: ShapeDraft.penShape(points: points, closed: closed, path: path),
                               anchors: points, isClosed: closed)
        layerError = nil
        commit(draft)
        if let layerError { throw layerError }
        guard let added = selectedLayerID else { throw FlareLayerError.noDocument }
        return added
    }
}
