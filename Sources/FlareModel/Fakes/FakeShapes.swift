// FakeShapes.swift: ShapeBuilding by hand (docs/blueprints/flare.md, 6.3). Rectangles and ellipses are polygons, a pen
// path is straight segments with dragged anchors marked smooth. Each write is one group named by section 2, of real
// FlareCore commands or `FixtureEdit` where FlareCore has none (path edit, instance delete). Box gestures follow the
// not-animated / animated rule; only shapes move by `translate`. The pasteboard holds `AddLayer` envelopes from
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
    /// Sides of a fake ellipse's polygon.
    public static let ellipseSides = 32
    /// How near the first pen anchor a click closes the path, in scene points.
    public static let closeDistance = 4.0

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
            ?? ShapeDraft(tool: .pen, shape: FlareShape(points: []))
        let (dx, dy) = (point.x - (draft.anchors.first?.x ?? .infinity), point.y - (draft.anchors.first?.y ?? 0))
        if draft.anchors.count >= 3, (dx * dx + dy * dy).squareRoot() <= Self.closeDistance {
            draft.isClosed = true
        } else {
            if dragged { draft.smoothAnchors.insert(draft.anchors.count) }
            draft.anchors.append(point)
        }
        draft.shape = FlareShape(points: draft.anchors, closed: draft.isClosed,
                                 fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), stroke: Stroke())
        return draft
    }

    public func commit(_ draft: ShapeDraft, sceneID: String, aboveLayerID: String?,
                       in engine: inout CommandEngine) throws -> String {
        try available()
        let kind = switch draft.tool {
        case .rectangle: "Rectangle"; case .ellipse: "Ellipse"; case .pen: "Path"
        case .select, .directSelect: throw CommandError.invalidDocument("Select doesn't draw.")
        }
        let owner = LayerOwner.scene(sceneID)
        let layers = engine.document.layers(of: owner) ?? []
        let above = layers.firstIndex { $0.id == aboveLayerID }
        if let aboveLayerID, above == nil { throw CommandError.layerNotFound(aboveLayerID) }
        if let above, layers[above].isLocked { throw CommandError.layerLocked(layers[above].id) }
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
        var result: [String: [String: Double]] = [:]
        for layer in document.layers(of: .scene(sceneID)) ?? [] where layers.contains(layer.id) {
            let t = layer.placement(at: Double(frame)).transform
            var values: [String: Double]
            switch gesture {
            case .move(let dx, let dy): values = ["x": t.x + dx, "y": t.y + dy]
            case .scale(let h, let to):
                let handle = ((h % 8) + 8) % 8, grip = Self.handle(handle, on: box), fixed = Self.handle(handle + 4, on: box)
                let sx = handle % 4 == 1 ? 1 : Self.ratio(to.x - fixed.x, grip.x - fixed.x)
                let sy = handle % 4 == 3 ? 1 : Self.ratio(to.y - fixed.y, grip.y - fixed.y)
                values = ["x": fixed.x + (t.x - fixed.x) * sx, "y": fixed.y + (t.y - fixed.y) * sy,
                          "scaleX": t.scaleX * sx, "scaleY": t.scaleY * sy]
            case .rotate(let degrees):
                let c = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2)
                let p = Matrix.rotation(degrees: degrees).apply(Point(x: t.x - c.x, y: t.y - c.y))
                values = ["x": c.x + p.x, "y": c.y + p.y, "rotation": t.rotation + degrees]
            }
            if values.values.allSatisfy(\.isFinite) { result[layer.id] = values }
        }
        return result
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
                    try engine.perform(SetKeyframe(sceneID: sceneID, layerID: layer.id, property: property,
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

    public func translate(_ items: [StageAddress], dx: Double, dy: Double, in engine: inout CommandEngine) throws {
        try available()
        try engine.group("Move") { engine in
            for a in Self.unique(items) {
                guard case .shape(let i) = a.item else { throw CommandError.invalidDocument("Only a shape moves here.") }
                try engine.perform(TranslateShape(owner: a.owner, layerID: a.layerID, index: i, dx: dx, dy: dy))
            }
        }
    }

    /// Removes the items, highest index first so the others keep theirs; their layers stay.
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
        var index = (engine.document.layers(of: owner) ?? []).firstIndex { $0.id == aboveLayerID }.map { $0 + 1 }
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
    /// `a / b`, or 1 when that is not a finite number.
    private static func ratio(_ a: Double, _ b: Double) -> Double { b != 0 && (a / b).isFinite ? a / b : 1 }
    /// Handle `h` (0...7 clockwise from top-left, taken mod 8) on `box`, where the stage draws it.
    public static func handle(_ h: Int, on box: Rect) -> Point {
        let midX = box.minX + box.width / 2, midY = box.minY + box.height / 2
        let spots = [(box.minX, box.minY), (midX, box.minY), (box.maxX, box.minY), (box.maxX, midY),
                     (box.maxX, box.maxY), (midX, box.maxY), (box.minX, box.maxY), (box.minX, midY)]
        let (x, y) = spots[((h % 8) + 8) % 8]  // never out of range
        return Point(x: x, y: y)
    }
    private static func corners(_ r: Rect) -> [Point] {
        [Point(x: r.minX, y: r.minY), Point(x: r.maxX, y: r.minY), Point(x: r.maxX, y: r.maxY), Point(x: r.minX, y: r.maxY)]
    }
    /// The ellipse inscribed in `r` as an `ellipseSides`-gon, starting at its right edge.
    private static func polygon(_ r: Rect) -> [Point] {
        let rx = r.width / 2, ry = r.height / 2, cx = r.minX + rx, cy = r.minY + ry
        let turns = (0..<ellipseSides).map { Matrix.rotation(degrees: Double($0) * 360 / Double(ellipseSides)) }
        return turns.map { Point(x: cx + rx * $0.a, y: cy + ry * $0.b) }  // a is the cosine, b the sine
    }
}
