// LiveStage.swift: the live `StageRendering` (docs/blueprints/flare.md, 6.2; live-stage task ST-1). The picture is
// FlareCore's render list (`Scene.renderList(at:symbols:)`, or the edited symbol's own), mapped item for item to
// `StageItem`s: visible layers in paint order, outlines as stored (cubics stay cubics), matrices and opacity already
// multiplied down. Text is listed with an empty path and counted in `hiddenTextCount`. No scene with that id gives
// a 0 × 0 list with no items.
import FlareCore

public struct LiveStage: StageRendering {
    public init() {}

    public func drawList(_ document: Document, sceneID: String, frame: Int,
                         editing symbolID: String?) -> StageDrawList {
        guard let scene = document.scenes.first(where: { $0.id == sceneID }) else {
            return StageDrawList(width: 0, height: 0, background: .white, items: [])
        }
        let at = Double(frame)
        let render: RenderList?
        if let symbolID {
            render = document.symbols.first(where: { $0.id == symbolID })?.renderList(at: at, symbols: document.symbols)
        } else {
            render = scene.renderList(at: at, symbols: document.symbols)
        }
        let items = (render?.items ?? []).map(Self.item)
        return StageDrawList(width: scene.width, height: scene.height, background: scene.background,
                             items: items, hiddenTextCount: items.count(where: \.isText))
    }

    /// One render item as a stage item. An item inside instances is addressed by the top instance it sits in, with
    /// the deeper instances' indices as its `instancePath`.
    private static func item(_ render: RenderItem) -> StageItem {
        let a = render.address
        let address: StageAddress
        if let top = a.hosts.first {
            address = StageAddress(owner: a.owner, layerID: top.layerID, item: .instance(top.instanceIndex),
                                   instancePath: a.hosts.dropFirst().map(\.instanceIndex))
        } else if let text = a.textIndex {
            address = StageAddress(owner: a.owner, layerID: a.layerID, item: .text(text))
        } else {
            address = StageAddress(owner: a.owner, layerID: a.layerID, item: .shape(a.shapeIndex ?? 0))
        }
        return StageItem(address: address, path: render.outline, fill: render.fill, stroke: render.stroke,
                         transform: render.matrix, opacity: render.opacity, isText: render.isText)
    }
}
