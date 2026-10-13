// LibraryContracts.swift: symbols, instances and swatches (docs/blueprints/flare.md, section 6.2).
import FlareCore

public struct SymbolSummary: Hashable, Sendable {
    public var id: String
    public var name: String
    public var durationFrames: Int
    public var usage: Int              // instances counted by walking every layer list
    public init(id: String, name: String, durationFrames: Int, usage: Int) {
        self.id = id; self.name = name; self.durationFrames = durationFrames; self.usage = usage
    }
}

public protocol LibraryManaging: Sendable {
    func symbols(_ document: Document) -> [SymbolSummary]
    func swatches(_ document: Document) -> [Swatch]
    /// Grouped "Convert to Symbol". Returns the symbol id.
    func convertToSymbol(_ layerIDs: [String], sceneID: String, name: String,
                         in engine: inout CommandEngine) throws -> String
    /// Single ("Place Symbol"). Throws on a locked layer.
    func placeInstance(of symbolID: String, at point: Point, owner: LayerOwner, layerID: String,
                       in engine: inout CommandEngine) throws -> StageAddress
    /// Coalescible.
    func setInstanceTransform(_ transform: Transform, at address: StageAddress,
                              coalesceKey: String?, in engine: inout CommandEngine) throws
    /// Single (`SetInstancePlayback`, LC-6).
    func setInstancePlayback(_ loop: Instance.LoopMode, firstFrame: Int, at address: StageAddress,
                             in engine: inout CommandEngine) throws
    /// Single.
    func renameSymbol(_ id: String, to name: String, in engine: inout CommandEngine) throws
    /// Single. Throws `symbolInUse` while any instance uses it.
    func removeSymbol(_ id: String, in engine: inout CommandEngine) throws
    /// Single.
    func addSwatch(_ swatch: Swatch, in engine: inout CommandEngine) throws
    /// Single.
    func removeSwatch(_ id: String, in engine: inout CommandEngine) throws
}
