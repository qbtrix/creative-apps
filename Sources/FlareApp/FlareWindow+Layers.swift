// FlareWindow+Layers.swift: the router's layers area
// (FlareWindow+Router.swift), the SCENES and LAYERS sidebar (layers-files
// LF-1): select a scene or layer, its eye and lock toggles, reorder and rename
// either kind of row by id, New Scene and New Layer. Remove takes a scene or a
// layer; a scene's Remove is refused with the Model's removeSceneHelp, which
// is also the remove control's tooltip. Duplicate waits for the row context
// menus (LF-2) and says so.
import FlareModel

extension FlareWindow {
    /// Acts on a layers intent.
    func performLayers(_ intent: FlareIntent.Layers) {
        switch intent {
        case .select(let id): model.selectItem(id)
        case .toggle(let id, let flag): if let flag = FlareLayerFlag(rawValue: flag) { model.toggleLayerFlag(id, flag) }
        // The sidebar selects one row at a time, so a drag moves one row.
        case .move(let section, let from, let to):
            if section == "scenes" { model.moveScene(from: from, to: to) }
            if section == "layers" { model.moveLayer(from: from, to: to) }
        case .rename(let id, let name):
            if isScene(id) { model.renameScene(id, to: name) } else { model.renameLayer(id, to: name) }
        case .addLayer: model.addLayer()
        case .addScene: model.addScene()
        case .remove(let id):
            if !isScene(id) { model.removeLayer(id) } else if model.removeSceneHelp(id) == nil { model.removeScene(id) }
        case .duplicate: break
        }
    }

    /// Why a layers intent can't act now; nil when it can.
    func layersHelp(_ intent: FlareIntent.Layers) -> String? {
        switch intent {
        case .select, .toggle, .move, .rename: nil
        case .addLayer: model.selectedScene == nil ? "Select a scene to add a layer to." : nil
        case .addScene: model.document == nil ? "Open an animation to add a scene to." : nil
        case .remove(let id): isScene(id) ? model.removeSceneHelp(id) : nil
        case .duplicate: "Duplicate comes with the row menus (F11a)."
        }
    }

    /// Whether `id` names a scene row rather than a layer row.
    private func isScene(_ id: String) -> Bool { model.scenes.contains { $0.id == id } }
}
