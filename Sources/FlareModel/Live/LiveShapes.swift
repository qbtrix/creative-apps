// LiveShapes.swift: the live shape tools, part one (docs/blueprints/flare/features/live-stage.md, task ST-6).
// Rectangle and Ellipse drafts are FlareCore's `PathBuilders` paths for the dragged box (Shift squares it, Option
// draws from the center); a Pen draft adds an anchor per click, and a drag makes that anchor smooth with mirrored
// handles (G1), so its segments are cubics; a click near the first anchor closes the path. A commit is one engine
// group, "Add Rectangle", "Add Ellipse" or "Add Path", of `AddLayer` and `AddShape`, with the layer id and name
// the fake gives ("rectangle-1", "Rectangle 1"), and throws `CommandError.layerLocked` above a locked layer.
// ST-8 and ST-9 add the box gestures and edits in their own files; ST-9 adds the `ShapeBuilding` conformance.
import FlareCore

public struct LiveShapes: Sendable {
    public init() {}

    /// How near the first pen anchor a click closes the path, in stage points (as the fake).
    static let closeDistance = 4.0
    /// How near two pen anchors are the same anchor, and the smallest pen extent that commits, in stage points.
    static let anchorTolerance = 1.0
    /// What `commit` throws for a pen path whose extent is under `anchorTolerance`.
    static let degeneratePath = "A path needs two points at least a point apart."

    /// Every tool draws; the workspace's `toolHelp` covers "no document".
    public func unavailableHelp(for tool: FlareTool) -> String? { nil }

    /// `previous` is the draft before this gesture began; only a pen draft carries on from it.
    public func draft(_ tool: FlareTool, from start: Point, to end: Point, modifiers: DragModifiers,
                      previous: ShapeDraft?) -> ShapeDraft? {
        guard start.isFinite, end.isFinite else { return nil }
        switch tool {
        case .select, .directSelect: return nil
        case .pen: return pen(at: start, to: end, previous: previous)
        case .rectangle, .ellipse:
            var dx = end.x - start.x, dy = end.y - start.y
            let side = max(abs(dx), abs(dy))
            if modifiers.contains(.shift) { (dx, dy) = (dx < 0 ? -side : side, dy < 0 ? -side : side) }
            let from = modifiers.contains(.option) ? Point(x: start.x - dx, y: start.y - dy) : start
            guard let box = Rect(enclosing: [from, Point(x: start.x + dx, y: start.y + dy)]),
                  box.width > 0, box.height > 0, box.width.isFinite, box.height.isFinite,
                  let path = try? (tool == .rectangle ? PathBuilders.rectangle(in: box) : PathBuilders.ellipse(in: box))
            else { return nil }
            var points = path.elements.compactMap(Self.end)
            if points.count > 1, points.last == points.first { points.removeLast() }
            return ShapeDraft(tool: tool, shape: FlareShape(points: points, closed: true, path: path))
        }
    }

    public func commit(_ draft: ShapeDraft, owner: LayerOwner, aboveLayerID: String?,
                       in engine: inout CommandEngine) throws -> String {
        let kind = switch draft.tool {
        case .rectangle: "Rectangle"; case .ellipse: "Ellipse"; case .pen: "Path"
        case .select, .directSelect: throw CommandError.invalidDocument("Select doesn't draw.")
        }
        if draft.tool == .pen, !Self.spans(draft.anchors, Self.scaled(Self.anchorTolerance, draft.stageScale)) {
            throw CommandError.invalidDocument(Self.degeneratePath)
        }
        let layers = engine.document.layers(of: owner) ?? []
        var index: Int?
        if let aboveLayerID {
            guard let i = layers.firstIndex(where: { $0.id == aboveLayerID }) else {
                throw CommandError.layerNotFound(aboveLayerID)
            }
            guard !layers[i].isLocked else { throw CommandError.layerLocked(aboveLayerID) }
            index = i + 1
        }
        // The fake's naming rule: the lowest n whose "<kind>-n" id and "<Kind> n" name are both free document-wide.
        let doc = engine.document
        let taken = Set((doc.scenes.flatMap(\.layers) + doc.symbols.flatMap(\.layers)).flatMap { [$0.id, $0.name] })
        var n = 1
        while taken.contains("\(kind.lowercased())-\(n)") || taken.contains("\(kind) \(n)") { n += 1 }
        let layer = Layer(id: "\(kind.lowercased())-\(n)", name: "\(kind) \(n)")
        try engine.group("Add \(kind)") {
            try $0.perform(AddLayer(owner: owner, layer: layer, index: index))
            try $0.perform(AddShape(owner: owner, layerID: layer.id, shape: draft.shape))
        }
        return layer.id
    }

    /// The pen path: a move to the first anchor, then a line to each corner anchor, or a cubic when either end is
    /// smooth. A smooth anchor's out-handle is where the drag ended and its in-handle that point mirrored through
    /// it. While a smooth first anchor stands alone, a trailing move keeps its out-handle (it draws nothing).
    private func pen(at point: Point, to drag: Point, previous: ShapeDraft?) -> ShapeDraft {
        var draft = previous.flatMap { $0.tool == .pen && !$0.isClosed ? $0 : nil }
            ?? ShapeDraft(tool: .pen, shape: FlareShape(points: []), stageScale: previous?.stageScale ?? 1)
        let tolerance = Self.scaled(Self.anchorTolerance, draft.stageScale)
        if let last = draft.anchors.last, Self.near(last, point, tolerance) { return draft }
        var elements = draft.shape.path?.elements ?? []
        if let first = draft.anchors.first, let last = draft.anchors.last, Self.distinct(draft.anchors, tolerance) >= 3,
           Self.near(first, point, Self.scaled(Self.closeDistance, draft.stageScale), inclusive: true) {
            draft.isClosed = true
            let firstIn = outHandle(0, of: draft, elements).map { Self.mirror($0, through: first) }
            if let segment = Self.segment(from: last, out: outHandle(draft.anchors.count - 1, of: draft, elements),
                                          to: first, in: firstIn) {
                elements.append(segment)
            }
            elements.append(.close)
        } else {
            let smooth = drag != point && drag.isFinite
            let out = smooth ? drag : nil
            if let last = draft.anchors.last {
                let lastOut = outHandle(draft.anchors.count - 1, of: draft, elements)
                if draft.anchors.count == 1 { elements = [.move(to: last)] }
                elements.append(Self.segment(from: last, out: lastOut, to: point, in: out.map { Self.mirror($0, through: point) })
                                ?? .line(to: point))
            } else {
                elements = [.move(to: point)] + (out.map { [.move(to: $0)] } ?? [])
            }
            if smooth { draft.smoothAnchors.insert(draft.anchors.count) }
            draft.anchors.append(point)
        }
        draft.shape = FlareShape(points: draft.anchors, closed: draft.isClosed,
                                 fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), path: FlarePath(elements: elements),
                                 stroke: Stroke())
        return draft
    }

    /// Anchor `i`'s out-handle, or nil for a corner: the first anchor's is the trailing move while it stands alone,
    /// else the first segment's first control; a later anchor's is its in-handle (the control before it) mirrored.
    private func outHandle(_ i: Int, of draft: ShapeDraft, _ elements: [PathElement]) -> Point? {
        guard draft.smoothAnchors.contains(i), draft.anchors.indices.contains(i) else { return nil }
        if i == 0 {
            guard elements.indices.contains(1) else { return nil }
            switch elements[1] { case .move(let p): return p; case .cubic(let c1, _, _): return c1; default: return nil }
        }
        guard elements.indices.contains(i), case .cubic(_, let c2, _) = elements[i] else { return nil }
        return Self.mirror(c2, through: draft.anchors[i])
    }

    /// A cubic from `a` to `b` when either has a handle, else nil (a straight segment).
    private static func segment(from a: Point, out: Point?, to b: Point, in handle: Point?) -> PathElement? {
        guard out != nil || handle != nil else { return nil }
        return .cubic(control1: out ?? a, control2: handle ?? b, to: b)
    }
    private static func mirror(_ p: Point, through a: Point) -> Point { Point(x: 2 * a.x - p.x, y: 2 * a.y - p.y) }
    /// `points` stage points in scene points at `stageScale`; +infinity for a degenerate scale.
    private static func scaled(_ points: Double, _ stageScale: Double) -> Double {
        guard stageScale > 0 else { return .infinity }  // also NaN
        let value = points / stageScale
        return value.isFinite ? value : .infinity
    }
    private static func end(_ e: PathElement) -> Point? {
        switch e { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; case .close: nil }
    }
    private static func near(_ a: Point, _ b: Point, _ tolerance: Double, inclusive: Bool = false) -> Bool {
        let d = (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y), t = tolerance * tolerance
        return inclusive ? d <= t : d < t
    }
    private static func distinct(_ points: [Point], _ tolerance: Double) -> Int {
        points.enumerated().filter { p in !points.prefix(p.offset).contains { near($0, p.element, tolerance) } }.count
    }
    private static func spans(_ points: [Point], _ tolerance: Double) -> Bool {
        let xs = points.map(\.x), ys = points.map(\.y)
        guard (xs + ys).allSatisfy(\.isFinite), let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max()
        else { return false }
        return x1 - x0 >= tolerance || y1 - y0 >= tolerance
    }
}
