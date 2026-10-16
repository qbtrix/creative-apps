// FlareWindow+Layers.swift: the router's layers area
// (FlareWindow+Router.swift). The sidebar's calls of today: select a scene or
// layer, its eye and lock toggles, reorder, rename and New Layer. Adding
// scenes, delete and duplicate wait for F11a (layers-files) and say so.
import FlareModel

extension FlareWindow {
    /// Acts on a layers intent.
    func performLayers(_ intent: FlareIntent.Layers) {
        switch intent {
        case .select(let id): model.selectItem(id)
        case .toggle(let id, let flag): if let flag = FlareLayerFlag(rawValue: flag) { model.toggleLayerFlag(id, flag) }
        // The sidebar selects one row at a time, so a drag moves one layer.
        case .move(let section, let from, let to): if section == "layers" { model.moveLayer(from: from, to: to) }
        case .rename(let id, let name): model.renameLayer(id, to: name)
        case .addLayer: model.addLayer()
        case .addScene, .remove, .duplicate: break
        }
    }

    /// Why a layers intent can't act now; nil for today's sidebar calls.
    func layersHelp(_ intent: FlareIntent.Layers) -> String? {
        switch intent {
        case .select, .toggle, .move, .rename: nil
        case .addLayer: model.selectedScene == nil ? "Select a scene to add a layer to." : nil
        case .addScene, .remove, .duplicate: "Not built yet (F11a)."
        }
    }
}
