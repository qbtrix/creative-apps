// FlarePen+Kernel.swift (pen-paths FP-1): the Pen's ShapeDraft as SuiteKernel's PenDraft, read and written as the shape
// LiveShapes draws, and `addPath` as one "Add Path" through the shapes service. FP-5 moves the Pen onto PenRules.
import FlareCore
import SuiteKernel

extension ShapeDraft {
    /// The pen draft as one contour at the stage scale; nil for another tool. Setting nil leaves the draft alone.
    public var pen: PenDraft? {
        get {
            guard tool == .pen else { return nil }
            let contours = shape.path?.contours ?? []
            var contour = contours.first ?? VectorContour(anchors: [], closed: isClosed)
            if anchors.count == 1, contours.count == 2, let handle = contours.last?.anchors.first?.point,
               contour.anchors.indices.contains(0) {
                contour.anchors[0].handleOut = handle
            }
            for index in contour.anchors.indices where smoothAnchors.contains(index) {
                let anchor = contour.anchors[index]
                if anchor.handleOut == nil, let handle = anchor.handleIn {
                    contour.anchors[index].handleOut = Point(x: 2 * anchor.point.x - handle.x, y: 2 * anchor.point.y - handle.y)
                }
            }
            contour.closed = isClosed
            return PenDraft(contour: contour, scale: stageScale)
        }
        set {
            guard let newValue else { return }
            let contour = newValue.contour
            anchors = contour.anchors.map(\.point)
            smoothAnchors = Set(contour.anchors.indices.filter {
                contour.anchors[$0].handleOut != nil || contour.anchors[$0].handleIn != nil
            })
            isClosed = contour.closed
            stageScale = newValue.scale
            var path = VectorPath(contours: [contour])
            if contour.anchors.count == 1, let handle = contour.anchors.first?.handleOut { path.elements.append(.move(to: handle)) }
            shape = Self.penShape(points: anchors, closed: isClosed, path: path)
        }
    }

    /// A pen path's shape as LiveShapes draws it: clear fill, the default stroke.
    static func penShape(points: [Point], closed: Bool, path: VectorPath) -> FlareShape {
        FlareShape(points: points, closed: closed, fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), path: path, stroke: Stroke())
    }
}

extension FlareWorkspace {
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
