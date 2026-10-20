// FlareWindow+Layers.swift: the router's layers area
// (FlareWindow+Router.swift), the SCENES and LAYERS sidebar (layers-files
// LF-1): select a scene or layer, its eye and lock toggles, reorder and rename
// either kind of row by id, New Scene and New Layer. Remove takes a scene or a
// layer; a scene's Remove is refused with the Model's removeSceneHelp, which
// is also the remove control's tooltip. SCENES is a SuiteSidebarList section;
// LAYERS is SuiteUI's LayerTreeList (adopt-kernel-layers AL-f3) over the
// kernel's `layerRows`, top first, named `.sidebar`: rows
// `suite.sidebar.row.<id>`, eye and lock `suite.sidebar.<id>.visible` /
// `.locked` (FlareLayerFlag's raw values). A reorder drop goes through the
// Model's `layerMove` onto the same `.move` intent the list drag sent before.
// Under the rows sits SuiteUI's LayerActionBar: New Layer, Duplicate, Delete,
// fx (waiting on layer styles), Lock and Hide for the selected layer
// (`flare.layers.bar.<part>`); a row's context menu holds Duplicate, Delete,
// Bring Forward, Send Backward, Lock and Hide. Each item is built from its
// catalog spec on the workspace (`layers.*`, `edit.duplicate`,
// `object.bring-forward`, `.send-backward`), titled by `menuTitle`, so its
// enablement and reason are the catalog's; a row's menu reads the workspace
// with that row selected, and a pick selects the row first.
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

/// The LAYERS panel: the shared list over the edited owner's layers, with eye, lock, rename and drag to reorder,
/// then the layer command bar. Every gesture leaves as an intent through `perform`.
struct FlareLayersList: View {
    let model: FlareWorkspace
    /// Whether the rows sit in the host's scroll view (a snapshot) rather than the list's own.
    var embedded = false
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LayerTreeList(
                rows: model.layerRows, childCount: { _ in 0 }, selection: model.selectedLayerID, naming: .sidebar,
                header: LayerTreeHeader(title: "Layers", action: nil),
                options: LayerTreeOptions(reorders: true, embedded: embedded),
                onSelect: { perform(.layers(.select(id: $0))) },
                onRename: { id, name in
                    perform(.layers(.rename(id: id, name: name)))
                    return nil
                },
                contextActions: { Self.rowMenu(model, row: $0, perform: perform) },
                onAction: act)
            LayerActionBar(Self.bar(model, perform: perform))
        }
    }

    /// The bar's catalog ids with their symbols and id parts.
    nonisolated static let barCommands: [(id: String, symbol: String, part: String)] = [
        ("layers.add", "plus", "new"), ("edit.duplicate", "plus.square.on.square", "duplicate"),
        ("layers.remove", "trash", "delete"), ("layers.toggle-locked", "lock", "lock"),
        ("layers.toggle-visible", "eye.slash", "visibility"),
    ]

    /// A row menu's catalog ids with their symbols.
    nonisolated static let rowCommands: [(id: String, symbol: String)] = [
        ("edit.duplicate", "plus.square.on.square"), ("layers.remove", "trash"),
        ("object.bring-forward", "square.2.layers.3d.top.filled"), ("object.send-backward", "square.2.layers.3d.bottom.filled"),
        ("layers.toggle-locked", "lock"), ("layers.toggle-visible", "eye.slash"),
    ]

    /// The intent catalog command `id` sends for layer `layer`.
    nonisolated static func intent(_ id: String, layer: String) -> FlareIntent? {
        switch id {
        case "layers.add": .layers(.addLayer)
        case "edit.duplicate": .edit(.duplicate)
        case "layers.remove": .layers(.remove(id: layer))
        case "layers.toggle-locked": .layers(.toggle(id: layer, flag: FlareLayerFlag.locked.rawValue))
        case "layers.toggle-visible": .layers(.toggle(id: layer, flag: FlareLayerFlag.visible.rawValue))
        case "object.bring-forward": .edit(.bringForward)
        case "object.send-backward": .edit(.sendBackward)
        default: nil
        }
    }

    /// The bar: each command from its spec on the workspace, fx after Delete, disabled until layer styles land.
    // view-static: main-actor
    static func bar(_ model: FlareWorkspace, perform: @escaping @MainActor (FlareIntent) -> Void) -> [ToolbarAction] {
        var actions = barCommands.compactMap { command in
            action(command.id, command.symbol, on: model, identifier: "flare.layers.bar." + command.part, perform: perform)
        }
        actions.insert(LayerActionBar.effects(identifier: "flare.layers.bar.fx"), at: 3)
        return actions
    }

    /// Row `id`'s context menu: each item from its spec with that row selected; a pick selects the row first.
    // view-static: main-actor
    static func rowMenu(_ model: FlareWorkspace, row id: String, perform: @escaping @MainActor (FlareIntent) -> Void) -> [ToolbarAction] {
        var row = model
        row.selectItem(id)
        return rowCommands.compactMap { command in
            action(command.id, command.symbol, on: row) { intent in
                perform(.layers(.select(id: id)))
                perform(intent)
            }
        }
    }

    /// Catalog command `id` as a panel item on `model`, sending its intent for the selected layer; nil for an id
    /// the catalog lacks (FlareLayerPanelCommandsTests holds every id to the catalog).
    // view-static: main-actor
    private static func action(_ id: String, _ symbol: String, on model: FlareWorkspace, identifier: String? = nil,
                               perform: @escaping @MainActor (FlareIntent) -> Void) -> ToolbarAction? {
        guard let spec = FlareWorkspace.catalog.spec(id) else { return nil }
        return ToolbarAction(spec, on: model, title: model.menuTitle(id), systemImage: symbol, identifier: identifier) {
            if let intent = intent(id, layer: model.selectedLayerID ?? "") { perform(intent) }
        }
    }

    private func act(_ action: LayerTreeAction) {
        switch action {
        case .toggleHidden(let id): perform(.layers(.toggle(id: id, flag: FlareLayerFlag.visible.rawValue)))
        case .toggleLocked(let id): perform(.layers(.toggle(id: id, flag: FlareLayerFlag.locked.rawValue)))
        case .move(let drop):
            if let move = model.layerMove(drop.id, parent: drop.parentID, index: drop.index) {
                perform(.layers(.move(section: "layers", from: move.from, to: move.to)))
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
