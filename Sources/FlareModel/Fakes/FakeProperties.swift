// FakeProperties.swift: PropertyAnimating over the real engine (docs/blueprints/flare.md, 6.3), with section 2's
// not-animated rule. No track or one key is not animated: an edit sets that one key (adding it at frame 0 when there is
// none), or keys the playhead with auto-key on. Two or more keys are animated: an edit keys the playhead. Keys are
// FlareCore's `SetKeyframe` and `RemoveKeyframe` on scene layers: the fake stays scene-only by choice, so a symbol
// owner throws; symbol keys are `LiveProperties`' job. Stroke has no FlareCore command, so it is one `FixtureEdit`. With `unavailable` set, reads are
// empty and every write throws it.
import FlareCore

public struct FakeProperties: PropertyAnimating {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// What the scene-only fakes throw for a key write on a symbol's layer; the live types write those keys.
    public static let symbolKeys = "Keys inside a symbol aren't supported yet."

    /// The inspector's TRANSFORM rows, in order: name, title, range, unit, decimals. Opacity is stored 0...1.
    public static let rows: [(name: String, title: String, range: ClosedRange<Double>, unit: String, decimals: Int)] = [
        ("x", "X", -10_000...10_000, "pt", 1), ("y", "Y", -10_000...10_000, "pt", 1),
        ("scaleX", "Scale X", -100...100, "×", 2), ("scaleY", "Scale Y", -100...100, "×", 2),
        ("rotation", "Rotation", -3600...3600, "°", 0), ("opacity", "Opacity", 0...1, "%", 0),
    ]

    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }

    /// The state of `property` on `layer` at `frame` by section 2's rule.
    public static func keyState(_ property: String, of layer: Layer, frame: Int) -> KeyState {
        let keys = layer.tracks[property] ?? []
        guard keys.count >= 2 else { return .notAnimated }
        return keys.contains { $0.frame == frame } ? .keyedHere : .animated
    }

    public func properties(_ document: Document, owner: LayerOwner, layerIDs: [String], frame: Int) -> [AnimatedProperty] {
        let layers = (document.layers(of: owner) ?? []).filter { layerIDs.contains($0.id) }
        guard unavailable == nil, !layers.isEmpty else { return [] }
        let samples = layers.map { $0.sample(at: Double(frame)) }
        return Self.rows.map { row in
            let values = samples.map { $0[row.name] ?? Layer.standardDefaults[row.name] ?? 0 }
            let states = layers.map { Self.keyState(row.name, of: $0, frame: frame) }
            let same = values.allSatisfy { $0 == values.first } && states.allSatisfy { $0 == states.first }
            // A Mixed row shows no marker, so it reads as not animated.
            return AnimatedProperty(name: row.name, title: row.title, value: same ? values.first : nil, range: row.range,
                                    unit: row.unit, decimals: row.decimals, keyState: same ? states.first ?? .notAnimated : .notAnimated)
        }
    }

    public func setValue(_ value: Double, of property: String, owner: LayerOwner, layerIDs: [String], frame: Int,
                         autoKey: Bool, coalesceKey: String?, in engine: inout CommandEngine) throws {
        try available()
        guard value.isFinite else { throw CommandError.invalidDocument("\(Self.title(property)) needs a number.") }
        let sceneID = try Self.scene(owner)
        let layers = try Self.layers(layerIDs, owner: owner, in: engine.document)
        func write(_ engine: inout CommandEngine) throws {
            for layer in layers {
                let keys = layer.tracks[property] ?? []
                let at = keys.count >= 2 || autoKey ? frame : keys.first?.frame ?? 0
                let easing = keys.first { $0.frame == at }?.easing ?? .linear
                try engine.perform(SetKeyframe(owner: .scene(sceneID), layerID: layer.id, property: property,
                                               keyframe: Keyframe(frame: at, value: value, easing: easing)),
                                   coalesceKey: coalesceKey)
            }
        }
        // Coalescible: top-level performs sharing the key make one entry. Without a key, several layers make one group.
        if coalesceKey == nil, layers.count > 1 { try engine.group("Set Keyframe", write) } else { try write(&engine) }
    }

    public func toggleAnimated(_ property: String, owner: LayerOwner, layerID: String, frame: Int, lastFrame: Int,
                               in engine: inout CommandEngine) throws {
        try available()
        let sceneID = try Self.scene(owner)
        guard let layer = try Self.layers([layerID], owner: owner, in: engine.document).first else { return }
        let keys = layer.tracks[property] ?? []
        let value = Self.value(property, of: layer, at: frame)
        func key(_ at: Int, _ engine: inout CommandEngine) throws {
            let easing = keys.first { $0.frame == at }?.easing ?? .linear
            try engine.perform(SetKeyframe(owner: .scene(sceneID), layerID: layerID, property: property,
                                           keyframe: Keyframe(frame: at, value: value, easing: easing)))
        }
        if keys.count >= 2 {
            // Stop: one key at frame 0 holding the value at the playhead.
            try engine.group("Stop Animating \(Self.title(property))") { engine in
                for k in keys where k.frame != 0 {
                    try engine.perform(RemoveKeyframe(owner: .scene(sceneID), layerID: layerID, property: property, frame: k.frame))
                }
                try key(0, &engine)
            }
        } else {
            // Start: key the playhead; if that leaves one key, key the last frame (or 0) too, so the row turns animated.
            try engine.group("Animate \(Self.title(property))") { engine in
                try key(frame, &engine)
                let other = frame == lastFrame ? 0 : lastFrame
                if keys.allSatisfy({ $0.frame == frame }), other != frame, other >= 0 { try key(other, &engine) }
            }
        }
    }

    public func toggleKey(_ property: String, owner: LayerOwner, layerID: String, frame: Int,
                          in engine: inout CommandEngine) throws {
        try available()
        let sceneID = try Self.scene(owner)
        guard let layer = try Self.layers([layerID], owner: owner, in: engine.document).first else { return }
        if layer.tracks[property]?.contains(where: { $0.frame == frame }) == true {
            try engine.perform(RemoveKeyframe(owner: .scene(sceneID), layerID: layerID, property: property, frame: frame))
        } else {
            try engine.perform(SetKeyframe(owner: .scene(sceneID), layerID: layerID, property: property,
                                           keyframe: Keyframe(frame: frame, value: Self.value(property, of: layer, at: frame))))
        }
    }

    public func setFill(_ fill: Fill, of items: [StageAddress], in engine: inout CommandEngine) throws {
        try available()
        try engine.group("Set Fill") { engine in
            for a in items { if case .shape(let i) = a.item {
                try engine.perform(SetShapeFill(owner: a.owner, layerID: a.layerID, index: i, fill: fill))
            } }
        }
    }

    public func setStroke(_ stroke: Stroke?, of items: [StageAddress], in engine: inout CommandEngine) throws {
        try available()
        let shapes = items.filter { if case .shape = $0.item { true } else { false } }
        guard !shapes.isEmpty else { return }
        try engine.group(stroke == nil ? "Remove Stroke" : "Set Stroke") { engine in
            try engine.perform(FixtureEdit("Set Stroke", from: engine.document) { doc in
                for a in shapes {
                    guard case .shape(let i) = a.item else { continue }
                    let layer = try Self.layers([a.layerID], owner: a.owner, in: doc).first
                    guard var layer, layer.shapes.indices.contains(i) else { throw CommandError.shapeNotFound(i) }
                    layer.shapes[i].stroke = stroke
                    try Self.replace(layer, owner: a.owner, in: &doc)
                }
            })
        }
    }

    /// The row title for `property`, or the name itself for a property with no row.
    public static func title(_ property: String) -> String { rows.first { $0.name == property }?.title ?? property }

    private static func value(_ property: String, of layer: Layer, at frame: Int) -> Double {
        layer.sample(at: Double(frame))[property] ?? Layer.standardDefaults[property] ?? 0
    }
    private static func scene(_ owner: LayerOwner) throws -> String {
        guard case .scene(let id) = owner else { throw CommandError.invalidDocument(symbolKeys) }
        return id
    }
    /// The layers named in `ids`, in the owner's order; throws when one is missing or locked.
    private static func layers(_ ids: [String], owner: LayerOwner, in document: Document) throws -> [Layer] {
        let all = document.layers(of: owner) ?? []
        for id in ids {
            guard let layer = all.first(where: { $0.id == id }) else { throw CommandError.layerNotFound(id) }
            guard !layer.isLocked else { throw CommandError.layerLocked(id) }
        }
        return all.filter { ids.contains($0.id) }
    }
    private static func replace(_ layer: Layer, owner: LayerOwner, in doc: inout Document) throws {
        switch owner {
        case .scene(let s):
            guard let i = doc.scenes.firstIndex(where: { $0.id == s }),
                  let j = doc.scenes[i].layers.firstIndex(where: { $0.id == layer.id }) else { throw CommandError.sceneNotFound(s) }
            doc.scenes[i].layers[j] = layer
        case .symbol(let s):
            guard let i = doc.symbols.firstIndex(where: { $0.id == s }),
                  let j = doc.symbols[i].layers.firstIndex(where: { $0.id == layer.id }) else { throw CommandError.symbolNotFound(s) }
            doc.symbols[i].layers[j] = layer
        }
    }
}
