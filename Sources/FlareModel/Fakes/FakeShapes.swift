// FakeShapes.swift: ShapeBuilding over the real engine (docs/blueprints/flare.md, 6.3). Rectangle and ellipse drafts are
// polygons, pen drafts straight segments with drag-made anchors marked smooth. Each write opens one group: new and
// duplicated layers by `AddLayer`, box gestures by `SetKeyframe` under section 2's not-animated rule. Copy writes
// `AddLayer` envelopes that paste reads back only through `CommandRegistry.builtIn`. Path edit, item move and delete
// still throw (#473). With `unavailable` set, drafts and reads are empty and every write throws that reason.
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

    /// What `paste` throws for data that holds no layers Flare can read.
    public static let nothingToPaste = "Nothing to paste."
    /// The fill a new shape gets.
    public static let defaultFill = Fill.solid(FlareColor(r: 0.36, g: 0.55, b: 0.95))
    /// How many corners an ellipse draft's polygon has.
    public static let ellipseSides = 32
    /// How close (scene points) a pen click must land to the first anchor to close the path.
    public static let closeDistance = 4.0

    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }

    public func unavailableHelp(for _: FlareTool) -> String? { unavailable }

    public func draft(_ tool: FlareTool, from start: Point, to end: Point, modifiers: DragModifiers,
                      previous: ShapeDraft?) -> ShapeDraft? {
        guard unavailable == nil, start.isFinite, end.isFinite else { return nil }
        switch tool {
        case .select: return nil
        case .pen: return penDraft(at: start, smooth: start != end, previous: previous)
        case .rectangle, .ellipse:
            var dx = end.x - start.x, dy = end.y - start.y
            if modifiers.contains(.shift) {
                let side = max(abs(dx), abs(dy))
                dx = dx < 0 ? -side : side; dy = dy < 0 ? -side : side
            }
            // Option draws from the center: the drag is half the box.
            let a = modifiers.contains(.option) ? Point(x: start.x - dx, y: start.y - dy) : start
            guard dx != 0, dy != 0, let box = Rect(enclosing: [a, Point(x: start.x + dx, y: start.y + dy)]) else { return nil }
            let points = tool == .rectangle ? Self.corners(box) : Self.ellipse(box)
            return ShapeDraft(tool: tool, shape: FlareShape(points: points, fill: Self.defaultFill))
        }
    }

    /// `previous` with an anchor at `point`, or closed when `point` lands on its first anchor.
    private func penDraft(at point: Point, smooth: Bool, previous: ShapeDraft?) -> ShapeDraft {
        var anchors: [Point] = [], smoothAnchors: Set<Int> = []
        if let previous, previous.tool == .pen, !previous.isClosed {
            anchors = previous.anchors; smoothAnchors = previous.smoothAnchors
        }
        let closes = anchors.count >= 2 && anchors.first.map {
            let dx = $0.x - point.x, dy = $0.y - point.y
            return dx * dx + dy * dy <= Self.closeDistance * Self.closeDistance
        } == true
        if !closes {
            if smooth { smoothAnchors.insert(anchors.count) }
            anchors.append(point)
        }
        let shape = FlareShape(points: anchors, closed: closes, fill: Self.defaultFill)
        return ShapeDraft(tool: .pen, shape: shape, anchors: anchors, smoothAnchors: smoothAnchors, isClosed: closes)
    }

    private static func corners(_ r: Rect) -> [Point] {
        [Point(x: r.minX, y: r.minY), Point(x: r.maxX, y: r.minY), Point(x: r.maxX, y: r.maxY), Point(x: r.minX, y: r.maxY)]
    }

    private static func ellipse(_ r: Rect) -> [Point] {
        let cx = (r.minX + r.maxX) / 2, cy = (r.minY + r.maxY) / 2, rx = r.width / 2, ry = r.height / 2
        return (0..<ellipseSides).map { i in
            let u = Matrix.rotation(degrees: Double(i) * 360 / Double(ellipseSides)).apply(Point(x: 1, y: 0))
            return Point(x: cx + rx * u.x, y: cy + ry * u.y)
        }
    }

    public func commit(_ draft: ShapeDraft, sceneID: String, aboveLayerID: String?,
                       in engine: inout CommandEngine) throws -> String {
        try available()
        let owner = LayerOwner.scene(sceneID)
        guard let layers = engine.document.layers(of: owner) else { throw CommandError.sceneNotFound(sceneID) }
        guard draft.shape.points.count >= 2 else { throw CommandError.invalidDocument("A shape needs two points.") }
        var index = layers.count
        if let aboveLayerID {
            guard let i = layers.firstIndex(where: { $0.id == aboveLayerID }) else { throw CommandError.layerNotFound(aboveLayerID) }
            guard !layers[i].isLocked else { throw CommandError.layerLocked(aboveLayerID) }
            index = i + 1
        }
        let kind = switch draft.tool { case .rectangle: "Rectangle"; case .ellipse: "Ellipse"; default: "Path" }
        var n = 1
        while layers.contains(where: { $0.name == "\(kind) \(n)" || $0.id == "\(kind.lowercased())-\(n)" }) { n += 1 }
        let layer = Layer(id: "\(kind.lowercased())-\(n)", name: "\(kind) \(n)", shapes: [draft.shape])
        try engine.group("Add \(kind)") { try $0.perform(AddLayer(owner: owner, layer: layer, index: index)) }
        return layer.id
    }

    public func boxResult(_ gesture: BoxGesture, layers: [String], document: Document, sceneID: String,
                          frame: Int, box: Rect) -> [String: [String: Double]] {
        guard unavailable == nil, let list = document.layers(of: .scene(sceneID)) else { return [:] }
        var result: [String: [String: Double]] = [:]
        for layer in list where layers.contains(layer.id) && !layer.isLocked {
            let t = layer.placement(at: Double(frame)).transform
            switch gesture {
            case let .move(dx, dy):
                result[layer.id] = ["x": t.x + dx, "y": t.y + dy]
            case let .scale(handle, to):
                let h = Self.handle(handle, of: box), o = Self.handle(handle + 4, of: box)
                // Each axis scales about the opposite handle; a middle handle leaves its other axis alone.
                func factor(_ from: Double, _ to: Double, _ origin: Double) -> Double {
                    let s = (to - origin) / (from - origin)
                    return s.isFinite ? s : 1
                }
                let sx = handle % 4 == 1 ? 1 : factor(h.x, to.x, o.x), sy = handle % 4 == 3 ? 1 : factor(h.y, to.y, o.y)
                result[layer.id] = ["x": o.x + (t.x - o.x) * sx, "y": o.y + (t.y - o.y) * sy,
                                    "scaleX": t.scaleX * sx, "scaleY": t.scaleY * sy]
            case let .rotate(degrees):
                let c = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2)
                let p = Matrix.rotation(degrees: degrees).apply(Point(x: t.x - c.x, y: t.y - c.y))
                result[layer.id] = ["x": c.x + p.x, "y": c.y + p.y, "rotation": t.rotation + degrees]
            }
        }
        return result
    }

    /// Handle `i` of `box`, 0...7 clockwise from the top-left corner (wrapping).
    private static func handle(_ i: Int, of box: Rect) -> Point {
        let midX = (box.minX + box.maxX) / 2, midY = (box.minY + box.maxY) / 2
        let all = [Point(x: box.minX, y: box.minY), Point(x: midX, y: box.minY), Point(x: box.maxX, y: box.minY),
                   Point(x: box.maxX, y: midY), Point(x: box.maxX, y: box.maxY), Point(x: midX, y: box.maxY),
                   Point(x: box.minX, y: box.maxY), Point(x: box.minX, y: midY)]
        return all[((i % 8) + 8) % 8]
    }

    public func commitBox(_ gesture: BoxGesture, layers: [String], sceneID: String, frame: Int, box: Rect,
                          autoKey: Bool, in engine: inout CommandEngine) throws {
        try available()
        let list = engine.document.layers(of: .scene(sceneID)) ?? []
        if let locked = list.first(where: { layers.contains($0.id) && $0.isLocked }) { throw CommandError.layerLocked(locked.id) }
        let values = boxResult(gesture, layers: layers, document: engine.document, sceneID: sceneID, frame: frame, box: box)
        let label = switch gesture { case .move: "Move"; case .scale: "Scale"; case .rotate: "Rotate" }
        try engine.group(label) { engine in
            for layer in list where values[layer.id] != nil {
                for (property, value) in (values[layer.id] ?? [:]).sorted(by: { $0.key < $1.key }) {
                    // Not animated (one key or none) with auto-key off: edit that one key, else key the playhead.
                    let track = layer.tracks[property] ?? []
                    let at = track.count >= 2 || autoKey ? frame : track.first?.frame ?? 0
                    let easing = track.first { $0.frame == at }?.easing ?? .linear
                    try engine.perform(SetKeyframe(sceneID: sceneID, layerID: layer.id, property: property,
                                                   keyframe: Keyframe(frame: at, value: value, easing: easing)))
                }
            }
        }
    }

    /// Path edit, item move and delete land in LM-0a2c (#473); until then they refuse.
    public static let itemEditsHelp = "Not built yet (LM-0a2c, #473)."

    public func setPath(_: FlarePath, of _: StageAddress, in _: inout CommandEngine) throws {
        try available(); throw NotBuilt(reason: Self.itemEditsHelp)
    }

    public func translate(_: [StageAddress], dx _: Double, dy _: Double, in _: inout CommandEngine) throws {
        try available(); throw NotBuilt(reason: Self.itemEditsHelp)
    }

    public func delete(_: [StageAddress], in _: inout CommandEngine) throws {
        try available(); throw NotBuilt(reason: Self.itemEditsHelp)
    }

    public func duplicate(layers: [String], owner: LayerOwner, in engine: inout CommandEngine) throws -> [String] {
        try available()
        var added: [String] = []
        try engine.group("Duplicate") { engine in
            for id in layers {
                let list = engine.document.layers(of: owner) ?? []
                guard let i = list.firstIndex(where: { $0.id == id }) else { throw CommandError.layerNotFound(id) }
                let copy = Self.fresh(list[i], among: list)
                try engine.perform(AddLayer(owner: owner, layer: copy, index: i + 1))
                added.append(copy.id)
            }
        }
        return added
    }

    public func copy(layers: [String], owner: LayerOwner, from document: Document) throws -> Data {
        try available()
        let list = document.layers(of: owner) ?? []
        if let missing = layers.first(where: { id in !list.contains { $0.id == id } }) { throw CommandError.layerNotFound(missing) }
        let envelopes = try list.filter { layers.contains($0.id) }.map {
            String(decoding: try CommandRegistry.builtIn.encode(AddLayer(owner: owner, layer: $0)), as: UTF8.self)
        }
        return try JSONEncoder().encode(envelopes)
    }

    public func paste(_ data: Data, owner: LayerOwner, aboveLayerID: String?, offset: Double,
                      in engine: inout CommandEngine) throws -> [String] {
        try available()
        let nothing = CommandError.invalidDocument(Self.nothingToPaste)
        guard let envelopes = try? JSONDecoder().decode([String].self, from: data), !envelopes.isEmpty else { throw nothing }
        let pasted = try envelopes.map { envelope in
            guard let add = try? CommandRegistry.builtIn.decode(Data(envelope.utf8)) as? AddLayer else { throw nothing }
            return add.layer
        }
        guard let start = engine.document.layers(of: owner) else { throw nothing }
        var index = start.count
        if let aboveLayerID {
            guard let i = start.firstIndex(where: { $0.id == aboveLayerID }) else { throw CommandError.layerNotFound(aboveLayerID) }
            index = i + 1
        }
        var added: [String] = []
        try engine.group("Paste") { engine in
            for var layer in pasted {
                // Shift the whole x track, or give the layer one x key if it had none.
                if offset != 0 {
                    let xs = layer.tracks["x"] ?? [Keyframe(frame: 0, value: Layer.standardDefaults["x"] ?? 0)]
                    layer.tracks["x"] = xs.map { Keyframe(frame: $0.frame, value: $0.value + offset, easing: $0.easing) }
                }
                let copy = Self.fresh(layer, among: engine.document.layers(of: owner) ?? [])
                try engine.perform(AddLayer(owner: owner, layer: copy, index: index + added.count))
                added.append(copy.id)
            }
        }
        return added
    }

    /// `layer` with an id and a name no layer in `list` has: its own name if free, else "<base> copy", then
    /// "<base> copy 2" and on, where base drops any " copy" or " copy <n>" already on the end.
    private static func fresh(_ layer: Layer, among list: [Layer]) -> Layer {
        func free(_ value: String, base: String, sep: String, taken: Set<String>) -> String {
            guard taken.contains(value) else { return value }
            var n = 1, candidate = base + sep + "copy"
            while taken.contains(candidate) { n += 1; candidate = base + sep + "copy" + sep + "\(n)" }
            return candidate
        }
        func base(_ name: String, _ sep: Character) -> String {
            var words = name.split(separator: sep, omittingEmptySubsequences: false).map(String.init)
            if words.count > 2, Int(words[words.count - 1]) != nil, words[words.count - 2] == "copy" { words.removeLast(2) }
            else if words.count > 1, words[words.count - 1] == "copy" { words.removeLast() }
            return words.joined(separator: String(sep))
        }
        var copy = layer
        copy.id = free(layer.id, base: base(layer.id, "-"), sep: "-", taken: Set(list.map(\.id)))
        copy.name = free(layer.name, base: base(layer.name, " "), sep: " ", taken: Set(list.map(\.name)))
        return copy
    }
}
