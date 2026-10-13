// FakeLibrary.swift: LibraryManaging over the real engine (docs/blueprints/flare.md, 6.3). Convert, remove and the
// swatches are FlareCore's own `ConvertToSymbol`, `RemoveSymbol`, `AddSwatch` and `RemoveSwatch`; placing an
// instance, its transform and playback, and renaming a symbol swap in an edited copy through `FixtureEdit` until
// FlareCore has those commands (LC-6, LC-12b). Usage is counted by walking every scene's and symbol's layers. With
// `unavailable` set, reads are empty and every write throws that reason.
import FlareCore

public struct FakeLibrary: LibraryManaging {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }

    public func symbols(_ document: Document) -> [SymbolSummary] {
        guard unavailable == nil else { return [] }
        let layers = document.scenes.flatMap(\.layers) + document.symbols.flatMap(\.layers)
        var usage: [String: Int] = [:]
        for instance in layers.flatMap(\.instances) { usage[instance.symbolID, default: 0] += 1 }
        return document.symbols.map {
            SymbolSummary(id: $0.id, name: $0.name, durationFrames: $0.durationFrames, usage: usage[$0.id] ?? 0)
        }
    }

    public func swatches(_ document: Document) -> [Swatch] { unavailable == nil ? document.swatches : [] }

    public func convertToSymbol(_ layerIDs: [String], sceneID: String, name: String,
                                in engine: inout CommandEngine) throws -> String {
        try available()
        // The smallest n that no symbol uses as an id.
        var n = 1
        while engine.document.symbols.contains(where: { $0.id == "symbol-\(n)" }) { n += 1 }
        let id = "symbol-\(n)"
        try engine.group("Convert to Symbol") {
            try $0.perform(ConvertToSymbol(sceneID: sceneID, layerIDs: layerIDs, symbolID: id, name: name))
        }
        return id
    }

    public func placeInstance(of symbolID: String, at point: Point, owner: LayerOwner, layerID: String,
                              in engine: inout CommandEngine) throws -> StageAddress {
        try available()
        guard engine.document.symbols.contains(where: { $0.id == symbolID }) else { throw CommandError.symbolNotFound(symbolID) }
        var index = 0
        // A symbol placed inside itself is a cycle, which the engine's validation refuses.
        try engine.perform(FixtureEdit("Place Symbol", from: engine.document) { doc in
            try Self.edit(owner, layerID, in: &doc) { layer in
                guard !layer.isLocked else { throw CommandError.layerLocked(layerID) }
                index = layer.instances.count
                layer.instances.append(Instance(symbolID: symbolID, transform: Transform(x: point.x, y: point.y)))
            }
        })
        return StageAddress(owner: owner, layerID: layerID, item: .instance(index))
    }

    public func setInstanceTransform(_ transform: Transform, at address: StageAddress,
                                     coalesceKey: String?, in engine: inout CommandEngine) throws {
        try available()
        try engine.perform(FixtureEdit("Transform Instance", from: engine.document) { doc in
            try Self.editInstance(address, in: &doc) { $0.transform = transform }
        }, coalesceKey: coalesceKey)
    }

    public func setInstancePlayback(_ loop: Instance.LoopMode, firstFrame: Int, at address: StageAddress,
                                    in engine: inout CommandEngine) throws {
        try available()
        guard firstFrame >= 0 else { throw CommandError.invalidFrame(firstFrame) }
        try engine.perform(FixtureEdit("Set Instance Playback", from: engine.document) { doc in
            try Self.editInstance(address, in: &doc) { $0.loop = loop; $0.firstFrame = firstFrame }
        })
    }

    public func renameSymbol(_ id: String, to name: String, in engine: inout CommandEngine) throws {
        try available()
        try engine.perform(FixtureEdit("Rename Symbol", from: engine.document) { doc in
            guard let i = doc.symbols.firstIndex(where: { $0.id == id }) else { throw CommandError.symbolNotFound(id) }
            doc.symbols[i].name = name
        })
    }

    public func removeSymbol(_ id: String, in engine: inout CommandEngine) throws {
        try available(); try engine.perform(RemoveSymbol(symbolID: id))
    }
    public func addSwatch(_ swatch: Swatch, in engine: inout CommandEngine) throws {
        try available(); try engine.perform(AddSwatch(name: swatch.name, color: swatch.color))
    }
    public func removeSwatch(_ id: String, in engine: inout CommandEngine) throws {
        try available(); try engine.perform(RemoveSwatch(name: id))
    }

    /// Runs `body` on the layer `layerID` of `owner` in `doc`; throws when either is missing.
    private static func edit(_ owner: LayerOwner, _ layerID: String, in doc: inout Document,
                             _ body: (inout Layer) throws -> Void) throws {
        func change(_ layers: inout [Layer]) throws {
            guard let j = layers.firstIndex(where: { $0.id == layerID }) else { throw CommandError.layerNotFound(layerID) }
            try body(&layers[j])
        }
        switch owner {
        case .scene(let id):
            guard let i = doc.scenes.firstIndex(where: { $0.id == id }) else { throw CommandError.sceneNotFound(id) }
            try change(&doc.scenes[i].layers)
        case .symbol(let id):
            guard let i = doc.symbols.firstIndex(where: { $0.id == id }) else { throw CommandError.symbolNotFound(id) }
            try change(&doc.symbols[i].layers)
        }
    }

    /// Runs `body` on the instance `address` names; throws when it names no instance.
    private static func editInstance(_ address: StageAddress, in doc: inout Document,
                                     _ body: (inout Instance) -> Void) throws {
        guard case .instance(let k) = address.item else { throw CommandError.invalidIndex(-1) }
        try edit(address.owner, address.layerID, in: &doc) { layer in
            guard layer.instances.indices.contains(k) else { throw CommandError.invalidIndex(k) }
            guard !layer.isLocked else { throw CommandError.layerLocked(layer.id) }
            body(&layer.instances[k])
        }
    }
}
