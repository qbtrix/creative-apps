// FakeLibrary.swift: LibraryManaging over the real engine (docs/blueprints/flare.md, 6.3). Convert to Symbol, delete
// and the swatches (a swatch's id is its name) are FlareCore's own commands; place, instance transform and playback,
// and rename have none yet (LC-6, LC-12b), so each is one `FixtureEdit`. `unavailable` empties reads, refuses writes.
import FlareCore

public struct FakeLibrary: LibraryManaging {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }

    public func symbols(_ document: Document) -> [SymbolSummary] {
        guard unavailable == nil else { return [] }
        // Usage: the instances on every layer of every scene and symbol.
        let used = (document.scenes.flatMap(\.layers) + document.symbols.flatMap(\.layers)).flatMap(\.instances).map(\.symbolID)
        return document.symbols.map { s in
            SymbolSummary(id: s.id, name: s.name, durationFrames: s.durationFrames, usage: used.filter { $0 == s.id }.count)
        }
    }

    public func swatches(_ document: Document) -> [Swatch] { unavailable == nil ? document.swatches : [] }

    public func convertToSymbol(_ layerIDs: [String], sceneID: String, name: String,
                                in engine: inout CommandEngine) throws -> String {
        try available()
        let name = try Self.named(name)
        let taken = Set(engine.document.symbols.map(\.id))
        let id = (1...).lazy.map { "symbol-\($0)" }.first { !taken.contains($0) } ?? "symbol"
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
        // A symbol placed inside itself, directly or not, fails the engine's cycle check and changes nothing.
        try Self.edit("Place Symbol", owner: owner, layerID: layerID, in: &engine) { layer in
            index = layer.instances.count
            layer.instances.append(Instance(symbolID: symbolID, transform: Transform(x: point.x, y: point.y)))
        }
        return StageAddress(owner: owner, layerID: layerID, item: .instance(index))
    }

    public func setInstanceTransform(_ transform: Transform, at address: StageAddress, coalesceKey: String?,
                                     in engine: inout CommandEngine) throws {
        try available()
        guard [transform.x, transform.y, transform.scaleX, transform.scaleY, transform.rotation].allSatisfy(\.isFinite) else {
            throw CommandError.invalidDocument("An instance needs finite numbers.")
        }
        try Self.editInstance("Transform Instance", at: address, coalesceKey: coalesceKey, in: &engine) { $0.transform = transform }
    }

    public func setInstancePlayback(_ loop: Instance.LoopMode, firstFrame: Int, at address: StageAddress,
                                    in engine: inout CommandEngine) throws {
        try available()
        guard firstFrame >= 0 else { throw CommandError.invalidDocument("The first frame can't be before 0.") }
        try Self.editInstance("Set Instance Playback", at: address, coalesceKey: nil, in: &engine) {
            $0.loop = loop; $0.firstFrame = firstFrame
        }
    }

    public func renameSymbol(_ id: String, to name: String, in engine: inout CommandEngine) throws {
        try available()
        let name = try Self.named(name)
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

    /// `name` without surrounding whitespace; throws when nothing else is left.
    static func named(_ name: String) throws -> String {
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty else { throw CommandError.invalidDocument("Type a name for the symbol.") }
        return trimmed
    }

    /// One `FixtureEdit` named `label` on layer `layerID` of `owner`; throws when it is missing or locked.
    private static func edit(_ label: String, owner: LayerOwner, layerID: String, coalesceKey: String? = nil,
                             in engine: inout CommandEngine, _ body: (inout Layer) throws -> Void) throws {
        try engine.perform(FixtureEdit(label, from: engine.document) { doc in
            func edit(_ layers: inout [Layer]) throws {
                guard let i = layers.firstIndex(where: { $0.id == layerID }) else { throw CommandError.layerNotFound(layerID) }
                guard !layers[i].isLocked else { throw CommandError.layerLocked(layerID) }
                try body(&layers[i])
            }
            switch owner {
            case .scene(let s):
                guard let i = doc.scenes.firstIndex(where: { $0.id == s }) else { throw CommandError.sceneNotFound(s) }
                try edit(&doc.scenes[i].layers)
            case .symbol(let s):
                guard let i = doc.symbols.firstIndex(where: { $0.id == s }) else { throw CommandError.symbolNotFound(s) }
                try edit(&doc.symbols[i].layers)
            }
        }, coalesceKey: coalesceKey)
    }

    /// `edit` on the instance at `address`; throws when the address is not an instance that exists.
    private static func editInstance(_ label: String, at address: StageAddress, coalesceKey: String?,
                                     in engine: inout CommandEngine, _ body: (inout Instance) -> Void) throws {
        guard case .instance(let index) = address.item else { throw CommandError.invalidIndex(-1) }
        try edit(label, owner: address.owner, layerID: address.layerID, coalesceKey: coalesceKey, in: &engine) { layer in
            guard layer.instances.indices.contains(index) else { throw CommandError.invalidIndex(index) }
            body(&layer.instances[index])
        }
    }
}
