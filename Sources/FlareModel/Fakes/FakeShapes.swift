// FakeShapes.swift: ShapeBuilding by hand (docs/blueprints/flare.md, 6.3). Rectangles and ellipses are polygons, a pen
// path is straight segments with dragged anchors marked smooth; a click within `anchorTolerance` stage points of its last
// anchor adds nothing, it closes on 3 anchors that far apart, and one whose extent is under it doesn't commit (#561), at
// the draft's fit scale (#619); a click within `closeDistance` stage points of its first anchor closes it (#649). Each write
// is one group named by section 2, of real FlareCore commands or `FixtureEdit` where FlareCore has none (path edit,
// instance move, instance delete); a move with a text item throws `textMove` before anything changes, as LiveShapes.
// Box gestures follow the not-animated / animated rule; a delete that empties a layer removes the layer. The pasteboard holds `AddLayer` envelopes from
// `CommandRegistry.builtIn`. With `unavailable` set, reads are empty and every write throws it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public struct FakeShapes: ShapeBuilding {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// What `paste` throws for data that holds no layer.
    public static let nothingToPaste = "Nothing to paste."
    /// What `translate` throws for a selection with a text item, as LiveShapes does; FlareCore has no text move.
    public static let textMove = "Text can't be moved yet."
    /// Sides of a fake ellipse's polygon.
    public static let ellipseSides = 32
    /// How near the first pen anchor a click closes the path, in stage (view) points: `FlareWorkspace.hitSlop`, so
    /// the close click lands the same on-screen distance off at any fit scale (#649).
    public static let closeDistance = 4.0
    /// `closeDistance` in scene points on a stage drawn at `stageScale` stage points per scene point, the pen draft's
    /// `stageScale`. A degenerate scale gives +infinity, as `anchorTolerance(atStageScale:)` does; no path closes
    /// then, since no second anchor lands.
    public static func closeDistance(atStageScale stageScale: Double) -> Double {
        guard stageScale > 0 else { return .infinity }  // also NaN
        let radius = closeDistance / stageScale
        return radius.isFinite ? radius : .infinity
    }
    /// How near two pen anchors are the same anchor, and the smallest extent a pen path commits at, in stage (view)
    /// points: `FlareWorkspace.clickSlop`, so a click's sub-point jitter stacks no anchor and commits no layer at any
    /// fit scale (#619).
    public static let anchorTolerance = 1.0
    /// `anchorTolerance` in scene points on a stage drawn at `stageScale` stage points per scene point, the pen
    /// draft's `stageScale`. A degenerate scale (zero, negative, NaN, -infinity, or one whose tolerance overflows)
    /// gives +infinity, so no second anchor lands and no path commits, as the ellipse minimum does.
    public static func anchorTolerance(atStageScale stageScale: Double) -> Double {
        guard stageScale > 0 else { return .infinity }  // also NaN
        let tolerance = anchorTolerance / stageScale
        return tolerance.isFinite ? tolerance : .infinity
    }
    /// What `commit` throws for a pen path whose extent is under `anchorTolerance`.
    public static let degeneratePath = "A path needs two points at least a point apart."

    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }
    public func unavailableHelp(for tool: FlareTool) -> String? { unavailable }

    /// `previous` is the draft before this gesture began; only a pen draft carries on from it.
    public func draft(_ tool: FlareTool, from start: Point, to end: Point, modifiers: DragModifiers,
                      previous: ShapeDraft?) -> ShapeDraft? {
        guard unavailable == nil, start.isFinite, end.isFinite else { return nil }
        switch tool {
        case .select, .directSelect: return nil
        case .pen: return pen(at: start, dragged: start != end, previous: previous)
        case .rectangle, .ellipse:
            var dx = end.x - start.x, dy = end.y - start.y
            let side = max(abs(dx), abs(dy))
            if modifiers.contains(.shift) { (dx, dy) = (dx < 0 ? -side : side, dy < 0 ? -side : side) }
            let from = modifiers.contains(.option) ? Point(x: start.x - dx, y: start.y - dy) : start
            guard let box = Rect(enclosing: [from, Point(x: start.x + dx, y: start.y + dy)]),
                  box.width > 0, box.height > 0, box.width.isFinite, box.height.isFinite else { return nil }
            return ShapeDraft(tool: tool, shape: FlareShape(points: tool == .rectangle ? Self.corners(box) : Self.polygon(box)))
        }
    }

    private func pen(at point: Point, dragged: Bool, previous: ShapeDraft?) -> ShapeDraft {
        var draft = previous.flatMap { $0.tool == .pen && !$0.isClosed ? $0 : nil }
            ?? ShapeDraft(tool: .pen, shape: FlareShape(points: []), stageScale: previous?.stageScale ?? 1)
        let tolerance = Self.anchorTolerance(atStageScale: draft.stageScale)
        // A click near the last anchor adds no near zero-length segment.
        if let last = draft.anchors.last, Self.near(last, point, tolerance) { return draft }
        let (dx, dy) = (point.x - (draft.anchors.first?.x ?? .infinity), point.y - (draft.anchors.first?.y ?? 0))
        if Self.distinct(draft.anchors, tolerance) >= 3, (dx * dx + dy * dy).squareRoot()
            <= Self.closeDistance(atStageScale: draft.stageScale) {
            draft.isClosed = true
        } else {
            if dragged { draft.smoothAnchors.insert(draft.anchors.count) }
            draft.anchors.append(point)
        }
        draft.shape = FlareShape(points: draft.anchors, closed: draft.isClosed,
                                 fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), stroke: Stroke())
        return draft
    }

    public func commit(_ draft: ShapeDraft, owner: LayerOwner, aboveLayerID: String?,
                       in engine: inout CommandEngine) throws -> String {
        try available()
        let kind = switch draft.tool {
        case .rectangle: "Rectangle"; case .ellipse: "Ellipse"; case .pen: "Path"
        case .select, .directSelect: throw CommandError.invalidDocument("Select doesn't draw.")
        }
        let tolerance = Self.anchorTolerance(atStageScale: draft.stageScale)
        if draft.tool == .pen, !Self.spans(draft.anchors, tolerance) || !Self.spans(draft.shape.points, tolerance) {
            throw CommandError.invalidDocument(Self.degeneratePath)
        }
        let above = try Self.anchor(aboveLayerID, owner: owner, in: engine.document)
        let taken = Self.taken(engine.document)
        var n = 1
        while taken.contains("\(kind.lowercased())-\(n)") || taken.contains("\(kind) \(n)") { n += 1 }
        let layer = Layer(id: "\(kind.lowercased())-\(n)", name: "\(kind) \(n)", shapes: [draft.shape])
        try engine.group("Add \(kind)") {
            try $0.perform(AddLayer(owner: owner, layer: layer, index: above.map { $0 + 1 }))
        }
        return layer.id
    }

    public func boxResult(_ gesture: BoxGesture, layers: [String], document: Document, sceneID: String,
                          frame: Int, box: Rect) -> [String: [String: Double]] {
        guard unavailable == nil else { return [:] }
        let list = FakeStage().drawList(document, sceneID: sceneID, frame: frame, editing: nil)
        return BoxGestureMath.result(gesture, layers: layers, document: document, sceneID: sceneID, frame: frame,
                                     box: box, list: list)
    }

    public func commitBox(_ gesture: BoxGesture, layers: [String], sceneID: String, frame: Int, box: Rect,
                          autoKey: Bool, in engine: inout CommandEngine) throws {
        try available()
        let label = switch gesture { case .move: "Move"; case .scale: "Scale"; case .rotate: "Rotate" }
        let document = engine.document
        let changes = boxResult(gesture, layers: layers, document: document, sceneID: sceneID, frame: frame, box: box)
        try engine.group(label) { engine in
            for layer in document.layers(of: .scene(sceneID)) ?? [] {
                for (property, value) in changes[layer.id]?.sorted(by: { $0.key < $1.key }) ?? [] {
                    // Two or more keys (or auto-key): key the playhead; otherwise edit the one key, or add it at 0.
                    let keys = layer.tracks[property] ?? []
                    let at = keys.count >= 2 || autoKey ? frame : keys.first?.frame ?? 0
                    let easing = keys.first { $0.frame == at }?.easing ?? .linear
                    try engine.perform(SetKeyframe(owner: .scene(sceneID), layerID: layer.id, property: property,
                                                   keyframe: Keyframe(frame: at, value: value, easing: easing)))
                }
            }
        }
    }

    public func setPath(_ path: FlarePath, of item: StageAddress, in engine: inout CommandEngine) throws {
        try available()
        guard case .shape = item.item else { throw CommandError.invalidDocument("Only a shape has a path.") }
        try engine.group("Edit Path") {
            try Self.editItem("Edit Path", item, in: &$0) { layer, i in
                guard layer.shapes.indices.contains(i) else { throw CommandError.shapeNotFound(i) }
                layer.shapes[i].path = path
                layer.shapes[i].points = path.elements.compactMap(Self.end)
            }
        }
    }

    /// Shapes move by `TranslateShape` and instances (transform x, y) by `FixtureEdit`; a selection with a text
    /// item throws `textMove` as a whole before anything changes, as LiveShapes does.
    public func translate(_ items: [StageAddress], dx: Double, dy: Double, in engine: inout CommandEngine) throws {
        try available()
        let picked = Self.unique(items)
        if picked.contains(where: { if case .text = $0.item { true } else { false } }) {
            throw CommandError.invalidDocument(Self.textMove)
        }
        try engine.group("Move") { engine in
            for a in picked {
                switch a.item {
                case .shape(let i):
                    try engine.perform(TranslateShape(owner: a.owner, layerID: a.layerID, index: i, dx: dx, dy: dy))
                case .text: throw CommandError.invalidDocument(Self.textMove)
                case .instance: try Self.editItem("Move", a, in: &engine) { layer, i in
                    guard layer.instances.indices.contains(i) else { throw CommandError.invalidIndex(i) }
                    layer.instances[i].transform.x += dx
                    layer.instances[i].transform.y += dy
                }
                }
            }
        }
    }

    /// Removes the items, highest index first so the others keep theirs; a layer left with no shapes, texts or
    /// instances goes too, in the same group.
    public func delete(_ items: [StageAddress], in engine: inout CommandEngine) throws {
        try available()
        let order = Self.unique(items).sorted { Self.index($0) > Self.index($1) }
        try engine.group("Delete") { engine in
            for a in order {
                switch a.item {
                case .shape(let i): try engine.perform(RemoveShape(owner: a.owner, layerID: a.layerID, index: i))
                case .text(let i): try engine.perform(RemoveTextShape(owner: a.owner, layerID: a.layerID, index: i))
                case .instance: try Self.editItem("Delete", a, in: &engine) { layer, i in
                    guard layer.instances.indices.contains(i) else { throw CommandError.invalidIndex(i) }
                    layer.instances.remove(at: i)
                }
                }
            }
            var emptied: [(owner: LayerOwner, id: String)] = []
            for a in order where !emptied.contains(where: { $0.owner == a.owner && $0.id == a.layerID }) {
                guard let layer = engine.document.layers(of: a.owner)?.first(where: { $0.id == a.layerID }),
                      layer.shapes.isEmpty, layer.texts.isEmpty, layer.instances.isEmpty else { continue }
                emptied.append((a.owner, a.layerID))
                try engine.perform(RemoveLayer(owner: a.owner, layerID: a.layerID))
            }
        }
    }

    public func duplicate(layers: [String], owner: LayerOwner, in engine: inout CommandEngine) throws -> [String] {
        try available()
        let originals = (engine.document.layers(of: owner) ?? []).filter { layers.contains($0.id) }
        var added: [String] = []
        try engine.group("Duplicate") { engine in
            for original in originals {
                let copy = Self.copied(original, in: engine.document)
                let index = engine.document.layers(of: owner)?.firstIndex { $0.id == original.id }
                try engine.perform(AddLayer(owner: owner, layer: copy, index: index.map { $0 + 1 }))
                added.append(copy.id)
            }
        }
        return added
    }

    public func copy(layers: [String], owner: LayerOwner, from document: Document) throws -> Data {
        try available()
        let picked = (document.layers(of: owner) ?? []).filter { layers.contains($0.id) }
        return try JSONEncoder().encode(picked.map { try CommandRegistry.builtIn.encode(AddLayer(owner: owner, layer: $0)) })
    }

    public func paste(_ data: Data, owner: LayerOwner, aboveLayerID: String?, offset: Double,
                      in engine: inout CommandEngine) throws -> [String] {
        try available()
        guard let envelopes = try? JSONDecoder().decode([Data].self, from: data), !envelopes.isEmpty,
              let adds = try? envelopes.map({ try CommandRegistry.builtIn.decode($0) as? AddLayer }),
              case let layers = adds.compactMap({ $0?.layer }), layers.count == adds.count
        else { throw CommandError.invalidDocument(Self.nothingToPaste) }
        var index = try Self.anchor(aboveLayerID, owner: owner, in: engine.document).map { $0 + 1 }
        var added: [String] = []
        try engine.group("Paste") { engine in
            for layer in layers {
                var copy = Self.copied(layer, in: engine.document)
                let xs = copy.tracks["x"] ?? [Keyframe(frame: 0, value: Layer.standardDefaults["x"] ?? 0)]
                copy.tracks["x"] = xs.map { Keyframe(frame: $0.frame, value: $0.value + offset, easing: $0.easing) }
                try engine.perform(AddLayer(owner: owner, layer: copy, index: index))
                index = index.map { $0 + 1 }
                added.append(copy.id)
            }
        }
        return added
    }

    /// The index of `aboveLayerID` in the owner's layers, or nil for none; throws when that layer is missing or locked.
    private static func anchor(_ aboveLayerID: String?, owner: LayerOwner, in document: Document) throws -> Int? {
        guard let aboveLayerID else { return nil }
        let layers = document.layers(of: owner) ?? []
        guard let i = layers.firstIndex(where: { $0.id == aboveLayerID }) else { throw CommandError.layerNotFound(aboveLayerID) }
        guard !layers[i].isLocked else { throw CommandError.layerLocked(aboveLayerID) }
        return i
    }
    /// Every layer id and name in the document, scenes and symbols alike.
    private static func taken(_ document: Document) -> Set<String> {
        Set((document.scenes.flatMap(\.layers) + document.symbols.flatMap(\.layers)).flatMap { [$0.id, $0.name] })
    }
    /// `layer` as "<name> copy", then "<name> copy 2" and on, an earlier " copy" or " copy N" dropped first.
    private static func copied(_ layer: Layer, in document: Document) -> Layer {
        let words = layer.name.split(separator: " ", omittingEmptySubsequences: false), count = words.count
        let numbered = count > 2 && words[count - 2] == "copy" && Int(words[count - 1]) != nil
        let base = words.dropLast(numbered ? 2 : count > 1 && words.last == "copy" ? 1 : 0).joined(separator: " ")
        let taken = taken(document)
        var n = 1
        func name(_ n: Int) -> String { n == 1 ? "\(base) copy" : "\(base) copy \(n)" }
        while taken.contains(name(n)) || taken.contains("\(layer.id)-copy-\(n)") { n += 1 }
        var copy = layer
        copy.id = "\(layer.id)-copy-\(n)"; copy.name = name(n)
        return copy
    }
    /// One `FixtureEdit` named `label` running `body` on the item's layer and index; throws when the layer is
    /// missing or locked.
    private static func editItem(_ label: String, _ a: StageAddress, in engine: inout CommandEngine,
                                 _ body: (inout Layer, Int) throws -> Void) throws {
        try engine.perform(FixtureEdit(label, from: engine.document) { doc in
            func edit(_ layers: inout [Layer]) throws {
                guard let i = layers.firstIndex(where: { $0.id == a.layerID }) else { throw CommandError.layerNotFound(a.layerID) }
                guard !layers[i].isLocked else { throw CommandError.layerLocked(a.layerID) }
                try body(&layers[i], index(a))
            }
            switch a.owner {
            case .scene(let s):
                guard let i = doc.scenes.firstIndex(where: { $0.id == s }) else { throw CommandError.sceneNotFound(s) }
                try edit(&doc.scenes[i].layers)
            case .symbol(let s):
                guard let i = doc.symbols.firstIndex(where: { $0.id == s }) else { throw CommandError.symbolNotFound(s) }
                try edit(&doc.symbols[i].layers)
            }
        })
    }
    private static func unique(_ items: [StageAddress]) -> [StageAddress] {
        items.enumerated().filter { !items.prefix($0.offset).contains($0.element) }.map(\.element)
    }
    private static func index(_ a: StageAddress) -> Int { switch a.item { case .shape(let i), .text(let i), .instance(let i): i } }
    private static func end(_ e: PathElement) -> Point? {
        switch e { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; case .close: nil }
    }
    /// How many points of `points` are not `near` an earlier one.
    private static func distinct(_ points: [Point], _ tolerance: Double) -> Int {
        points.enumerated().filter { p in !points.prefix(p.offset).contains { near($0, p.element, tolerance) } }.count
    }
    /// Whether `a` and `b` are under `tolerance` scene points apart.
    private static func near(_ a: Point, _ b: Point, _ tolerance: Double) -> Bool {
        (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) < tolerance * tolerance
    }
    /// Whether `points` are all finite and span at least `tolerance` scene points across or down.
    private static func spans(_ points: [Point], _ tolerance: Double) -> Bool {
        let xs = points.map(\.x), ys = points.map(\.y)
        guard (xs + ys).allSatisfy(\.isFinite), let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max()
        else { return false }
        return x1 - x0 >= tolerance || y1 - y0 >= tolerance
    }
    /// Handle `h` (0...7 clockwise from top-left, taken mod 8) on `box`, where the stage draws it.
    public static func handle(_ h: Int, on box: Rect) -> Point { BoxGestureMath.handle(h, on: box) }
    private static func corners(_ r: Rect) -> [Point] { BoxGestureMath.corners(r) }
    /// The ellipse inscribed in `r` as an `ellipseSides`-gon, starting at its right edge.
    private static func polygon(_ r: Rect) -> [Point] {
        let rx = r.width / 2, ry = r.height / 2, cx = r.minX + rx, cy = r.minY + ry
        let turns = (0..<ellipseSides).map { Matrix.rotation(degrees: Double($0) * 360 / Double(ellipseSides)) }
        return turns.map { Point(x: cx + rx * $0.a, y: cy + ry * $0.b) }  // a is the cosine, b the sine
    }
}
