// FlareWindow+Layers.swift: the router's layers area
// (FlareWindow+Router.swift), the SCENES and LAYERS sidebar (layers-files
// LF-1): select a scene or layer, its eye and lock toggles, reorder and rename
// either kind of row by id, New Scene and New Layer. Remove takes a scene or a
// layer; a scene's Remove is refused with the Model's removeSceneHelp, which
// is also the remove control's tooltip. Right-clicking a row opens its context
// menu (LF-2), the Model's `layerRowMenu` / `sceneRowMenu` as ToolbarActions,
// each off with its reason. SCENES is a SuiteSidebarList section; LAYERS is
// SuiteUI's LayerTreeList (adopt-kernel-layers AL-f3) over the kernel's
// `layerRows`, top first, named `.sidebar`: rows `suite.sidebar.row.<id>`,
// eye and lock `suite.sidebar.<id>.visible` / `.locked` (FlareLayerFlag's raw
// values), New Layer in its header. A reorder drop goes through the Model's
// `layerMove` onto the same `.move` intent the list drag sent before.
import FlareModel
import SuiteUI
import SwiftUI

extension SidebarSection {
    /// The SCENES section. New Scene shows while an animation is open and sends `.addScene` through `perform`.
    static func flareScenes(_ model: FlareWorkspace, perform: @escaping @MainActor (FlareIntent.Layers) -> Void) -> SidebarSection {
        SidebarSection(
            id: "scenes", title: "Scenes",
            items: model.scenes.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "film") },
            addAction: model.document == nil
                ? nil : ToolbarAction("New Scene", systemImage: "plus") { perform(.addScene) })
    }
}

/// A row's context menu items as ToolbarActions that send their intent through `perform`.
enum FlareRowMenu {
    static func actions(_ commands: [FlareRowCommand], perform: @escaping @MainActor (FlareIntent.Layers) -> Void) -> [ToolbarAction] {
        commands.map { command in
            ToolbarAction(command.title, systemImage: command.systemImage, unavailableHelp: command.help) {
                perform(command.intent)
            }
        }
    }
}

/// The LAYERS panel: the shared list over the edited owner's layers, with eye, lock, rename and drag to reorder.
/// New Layer shows while a scene is selected. Every gesture leaves as a `.layers` intent through `perform`.
struct FlareLayersList: View {
    let model: FlareWorkspace
    /// Whether the rows sit in the host's scroll view (a snapshot) rather than the list's own.
    var embedded = false
    let perform: @MainActor (FlareIntent.Layers) -> Void

    var body: some View {
        LayerTreeList(
            rows: model.layerRows, childCount: { _ in 0 }, selection: model.selectedLayerID, naming: .sidebar,
            header: LayerTreeHeader(
                title: "Layers",
                action: model.selectedScene == nil
                    ? nil : ToolbarAction("New Layer", systemImage: "plus") { perform(.addLayer) }),
            options: LayerTreeOptions(reorders: true, embedded: embedded, dimsLocked: true),
            onSelect: { perform(.select(id: $0)) },
            onRename: { id, name in
                perform(.rename(id: id, name: name))
                return nil
            },
            contextActions: { FlareRowMenu.actions(model.layerRowMenu($0), perform: perform) },
            onAction: act)
    }

    private func act(_ action: LayerTreeAction) {
        switch action {
        case .toggleHidden(let id): perform(.toggle(id: id, flag: FlareLayerFlag.visible.rawValue))
        case .toggleLocked(let id): perform(.toggle(id: id, flag: FlareLayerFlag.locked.rawValue))
        case .move(let drop):
            if let move = model.layerMove(drop.id, parent: drop.parentID, index: drop.index) {
                perform(.move(section: "layers", from: move.from, to: move.to))
            }
        // Flare's layers are flat: no row discloses.
        case .disclose: break
        }
    }
}

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
        case .duplicate(let id): model.duplicateLayer(id)
        }
    }

    /// Why a layers intent can't act now; nil when it can.
    func layersHelp(_ intent: FlareIntent.Layers) -> String? {
        switch intent {
        case .select, .toggle, .move, .rename: nil
        case .addLayer: model.selectedScene == nil ? "Select a scene to add a layer to." : nil
        case .addScene: model.document == nil ? "Open an animation to add a scene to." : nil
        case .remove(let id): isScene(id) ? model.removeSceneHelp(id) : nil
        case .duplicate(let id): model.layerRowMenu(id).first { $0.intent == intent }?.help
        }
    }

    /// Whether `id` names a scene row rather than a layer row.
    private func isScene(_ id: String) -> Bool { model.scenes.contains { $0.id == id } }
}
