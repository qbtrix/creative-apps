// LiveHits.swift: live hit testing, part one (docs/blueprints/flare/features/live-stage.md, task ST-3). `hit` asks
// FlareCore's render list for the topmost item under the point with the pointer tolerance (LC-2): the scene's list,
// or the edited symbol's own list while one is edited in place. The core skips locked and text items, and hidden
// layers are absent from its list. An item inside an instance answers as that instance on the owner's layer, the
// selectable thing. ST-4 adds `marquee`, `bounds` and the `StageHitTesting` conformance in their own file.
import FlareCore

public struct LiveHits: Sendable {
    public init() {}

    /// The topmost unlocked, visible, non-text item at `point` (scene points), with `tolerance` added to its stroke
    /// and fill edge; nil on empty stage, an unknown scene or symbol, or a negative or non-finite tolerance.
    public func hit(_ document: Document, sceneID: String, frame: Int, editing symbolID: String?, at point: Point,
                    tolerance: Double) -> StageAddress? {
        guard let list = Self.renderList(document, sceneID, frame, symbolID) else { return nil }
        return list.hit(point, tolerance: tolerance).flatMap(Self.address)
    }

    /// The scene's render list, or the edited symbol's; nil when the scene or symbol is missing.
    static func renderList(_ document: Document, _ sceneID: String, _ frame: Int, _ symbolID: String?) -> RenderList? {
        guard let scene = document.scenes.first(where: { $0.id == sceneID }) else { return nil }
        guard let symbolID else { return scene.renderList(at: Double(frame), symbols: document.symbols) }
        return document.symbols.first { $0.id == symbolID }?.renderList(at: Double(frame), symbols: document.symbols)
    }

    /// The stage address of a core address: a top-level shape or text as itself, anything inside an instance as
    /// the outermost instance.
    static func address(_ core: RenderAddress) -> StageAddress? {
        if let host = core.hosts.first {
            return StageAddress(owner: core.owner, layerID: host.layerID, item: .instance(host.instanceIndex))
        }
        if let shape = core.shapeIndex { return StageAddress(owner: core.owner, layerID: core.layerID, item: .shape(shape)) }
        if let text = core.textIndex { return StageAddress(owner: core.owner, layerID: core.layerID, item: .text(text)) }
        return nil
    }
}
