// LiveShapes.swift: the live shape tools, part one (docs/blueprints/flare/features/live-stage.md, task ST-6).
// Rectangle and Ellipse drafts, and every kind `shape` draws, are the kernel's `ShapeRules.path` in the box
// `ShapeRules.dragged` gives (Shift squares it, Option draws from the center; shape-tools FS-5, rule 20); a Pen draft is
// the kernel's `PenRules` through `ShapeDraft.penDraft` (pen-paths FP-5, FlarePen+Kernel.swift). A commit is one engine
// group, "Add Rectangle", "Add Ellipse" or "Add Path", of `AddLayer` and `AddShape`, with the layer id and name
// the fake gives ("rectangle-1", "Rectangle 1"), and throws `CommandError.layerLocked` above a locked layer. The same
// group keys the new layer's position (`x` and `y`, at their standard values) once at frame 0, so an auto-key edit at a
// later frame keeps 0 and the shape animates (#1731).
// ST-8 and ST-9 add the box gestures and edits in their own files; ST-9 adds the `ShapeBuilding` conformance.
import FlareCore
import SuiteKernel

public struct LiveShapes: Sendable {
    public init() {}

    /// The tracks a new shape keys once at frame 0: its position.
    static let positionKeys = ["x", "y"]

    /// Every tool draws; the workspace's `toolHelp` covers "no document".
    public func unavailableHelp(for tool: FlareTool) -> String? { nil }

    /// `previous` is the draft before this gesture began; only a pen draft carries on from it.
    public func draft(_ tool: FlareTool, from start: Point, to end: Point, modifiers: DragModifiers,
                      previous: ShapeDraft?) -> ShapeDraft? {
        guard start.isFinite, end.isFinite else { return nil }
        switch tool {
        case .select, .directSelect, .shape: return nil
        case .pen: return ShapeDraft.penDraft(at: start, to: end, previous: previous)
        case .rectangle, .ellipse:
            return Self.shape(.defaults(tool == .rectangle ? .rectangle : .ellipse), from: start, to: end,
                              modifiers: modifiers).map { ShapeDraft(tool: tool, shape: $0) }
        }
    }

    /// `spec`'s shape for a drag: the kernel's `ShapeRules.dragged` box (Shift squares it or snaps a line to 45°,
    /// Option grows it from the centre) and `ShapeRules.path` in it, with the path's end points as the shape's points.
    /// `spec` keeps its options; a line's ends come from the drag. Nil for an empty drag, a closed kind without area,
    /// or a spec the kernel refuses. A line or an arrow is open, stroked and unfilled.
    public static func shape(_ spec: ShapeSpec, from start: Point, to end: Point,
                             modifiers: DragModifiers) -> FlareShape? {
        var keys: EditModifiers = []
        if modifiers.contains(.shift) { keys.insert(.shift) }
        if modifiers.contains(.option) { keys.insert(.option) }
        guard start.isFinite, end.isFinite,
              let (box, dragged) = ShapeRules.dragged(spec.kind, from: start, to: end, modifiers: keys) else { return nil }
        let open = spec.kind == .line || spec.kind == .arrow
        guard open || (box.width > 0 && box.height > 0) else { return nil }
        var drawn = spec
        (drawn.start, drawn.end) = (dragged.start, dragged.end)
        guard let path = try? ShapeRules.path(drawn, in: box) else { return nil }
        var points = path.elements.compactMap(Self.end)
        if points.count > 1, points.last == points.first { points.removeLast() }
        guard open else { return FlareShape(points: points, closed: true, path: path) }
        return FlareShape(points: points, closed: false, fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)),
                          path: path, stroke: Stroke())
    }

    public func commit(_ draft: ShapeDraft, owner: LayerOwner, aboveLayerID: String?,
                       in engine: inout CommandEngine) throws -> String {
        let kind = switch draft.tool {
        case .rectangle: "Rectangle"; case .ellipse: "Ellipse"; case .pen: "Path"
        case .select, .directSelect: throw CommandError.invalidDocument("Select doesn't draw.")
        case .shape: throw CommandError.invalidDocument(FlareTool.shapeHelp)
        }
        try draft.checkPenPath()
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
            for property in Self.positionKeys {
                let key = Keyframe(frame: 0, value: Layer.standardDefaults[property] ?? 0)
                try $0.perform(SetKeyframe(owner: owner, layerID: layer.id, property: property, keyframe: key))
            }
        }
        return layer.id
    }

    private static func end(_ e: PathElement) -> Point? {
        switch e { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; case .close: nil }
    }
}
