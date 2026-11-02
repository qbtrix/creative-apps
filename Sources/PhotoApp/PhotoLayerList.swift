// PhotoLayerList.swift: Photo's layer list on SuiteUI's LayerTreeList (AL-p3):
// the stack top first, each row with its eye, kind symbol and caption (info
// line, blend summary), a drop reordering through `layerListMove`. Under it
// SuiteUI's LayerActionBar: New Layer, Duplicate Layer, Delete Layer, fx
// (waiting on layer styles), Show/Hide Layer and Rename Layer…
// (`photo.layer.new`, `.duplicate`, `.delete`, `.fx`, `.visibility`,
// `.rename`). A row's context menu holds Rename, Duplicate, Delete, Merge
// Down, Flatten Image, Bring Forward, Send Backward and Show/Hide. Every item
// is built from the Layer menu's catalog spec on the same state,
// `ToolbarAction(spec, on:)` titled as the menu titles it, so its title,
// enablement and reason are the menu's; a row's menu reads the workspace with
// that row selected (a row already picked keeps every pick, as Delete and Hide
// act on all of them), and a pick selects an unpicked row, then runs. Every
// picked layer draws selected, and a row click leaves as `pickLayer` with its
// mode (multi-layer-select PM-3). Values in, intents out. In a window it reads
// the PhotoSession's `document` facet; without one (the snapshots) the
// workspace it was given.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The layer rows, then the row of layer commands.
struct PhotoLayerList: View {
    private let given: PhotoWorkspace
    let perform: PhotoPerform
    @Environment(PhotoSession.self) private var session: PhotoSession?

    init(model: PhotoWorkspace, perform: @escaping PhotoPerform) {
        (given, self.perform) = (model, perform)
    }

    /// The window's workspace now, read through the `document` facet; the given one outside a window.
    private var model: PhotoWorkspace { session?.workspace(reading: .document) ?? given }

    var body: some View {
        let model = self.model
        let menu = PhotoMenu(model: model, perform: perform)
        VStack(alignment: .leading, spacing: 0) {
            LayerTreeList(
                rows: model.layerRows, childCount: { _ in 0 }, selected: Self.selected(model),
                naming: PhotoLayerRow.naming, options: PhotoLayerRow.options,
                decorations: Self.decorations(model), onPick: { perform(.pickLayer($0, $1)) },
                contextActions: { Self.rowMenu(menu, row: $0) }
            ) { action in
                switch action {
                case .toggleHidden(let id): perform(.toggleVisibility(id))
                case .move(let drop):
                    if let move = model.layerListMove(drop.id, parent: drop.parentID, index: drop.index) {
                        perform(.moveLayers(IndexSet(integer: move.offset), move.destination))
                    }
                case .disclose, .toggleLocked: break
                }
            }
            LayerActionBar(Self.bar(menu))
        }
    }

    /// The rows drawn picked: every selected layer's id.
    nonisolated static func selected(_ model: PhotoWorkspace) -> Set<String> {
        Set(model.selectedLayerIDs)
    }

    /// Each layer's kind symbol and caption by id; help names blend and opacity.
    nonisolated static func decorations(_ model: PhotoWorkspace) -> [String: LayerRowDecoration] {
        Dictionary(model.layers.map { layer -> (String, LayerRowDecoration) in
            let blend = model.layerBlendSummary(layer.id)
            return (layer.id, LayerRowDecoration(
                symbol: PhotoLayerRow.kindSymbol(layer.kind), symbolLabel: PhotoLayerRow.kindLabel(layer.kind),
                symbolID: PhotoLayerRow.kindIdentifier(layer.id), caption: model.layerCaption(layer.id),
                help: blend?.help, value: blend?.help))
        }) { first, _ in first }
    }

    /// One panel command: its catalog id, its id suffix after `photo.layer.`, and its intent.
    typealias Command = (id: String, part: String, intent: PhotoIntent?)

    /// The bar's commands, then fx after the third.
    nonisolated static func barCommands(selected: PhotoLayer.ID?) -> [Command] {
        [("layer.new", "new", .addLayer), ("layer.duplicate", "duplicate", .edit(.duplicateLayer)),
         ("layer.delete", "delete", .deleteLayer),
         ("layer.toggle-visibility", "visibility", selected.map(PhotoIntent.toggleVisibility)),
         ("layer.rename", "rename", .renameLayer)]
    }

    /// The row menu's commands for the layer `row`.
    nonisolated static func rowCommands(row: PhotoLayer.ID) -> [Command] {
        [("layer.rename", "rename", .renameLayer), ("layer.duplicate", "duplicate", .edit(.duplicateLayer)),
         ("layer.delete", "delete", .deleteLayer), ("layer.merge-down", "merge-down", .edit(.mergeDown)),
         ("layer.flatten", "flatten", .edit(.flattenImage)), ("layer.bring-forward", "bring-forward", .bringForward),
         ("layer.send-backward", "send-backward", .sendBackward),
         ("layer.toggle-visibility", "visibility", .toggleVisibility(row))]
    }

    /// The bar: each command as its Layer menu item on the selection, fx disabled until layer styles land.
    // view-static: main-actor
    static func bar(_ menu: PhotoMenu) -> [ToolbarAction] {
        var actions = barCommands(selected: menu.selectedLayer).map { action(menu, $0, in: menu.state()) }
        actions.insert(LayerActionBar.effects(identifier: "photo.layer.fx"), at: 3)
        return actions
    }

    /// Row `id`'s context menu: each item as the Layer menu shows it with that row selected; a pick selects it
    /// first. A row already picked keeps every pick, so the menu acts on all of them.
    // view-static: main-actor
    static func rowMenu(_ menu: PhotoMenu, row id: PhotoLayer.ID) -> [ToolbarAction] {
        var state = menu.state()
        let picked = state.workspace.selectedLayerIDs.contains(id)
        if !picked { state.workspace.selectLayer(id) }
        return rowCommands(row: id).map { action(menu, $0, in: state, selecting: picked ? nil : id) }
    }

    /// `command` from its catalog spec on `state`, titled as the Layer menu titles it; a pick selects `selecting` first.
    // view-static: main-actor
    private static func action(_ menu: PhotoMenu, _ command: Command, in state: PhotoMenuState,
                               selecting row: PhotoLayer.ID? = nil) -> ToolbarAction {
        let title = state.title(command.id)
        return ToolbarAction(
            PhotoMenuState.spec(command.id), on: state, title: title,
            systemImage: PhotoLayerMenu.symbol(command.id, visibility: title), identifier: "photo.layer." + command.part
        ) {
            if let row { menu.perform(.selectLayer(row)) }
            if let intent = command.intent { menu.perform(intent) }
        }
    }
}

/// A Layers row's ids (`photo.layers`, `photo.layer.row.<id>`,
/// `photo.layer.<id>.<part>`), eye, no lock, reordering, no nesting, and kind symbol.
enum PhotoLayerRow {
    static let naming = LayerTreeNaming.app(
        LayerTreeIDs(container: "photo.layers", row: "photo.layer.row.", control: "photo.layer."))
    static let options = LayerTreeOptions(showsEye: true, showsLock: false, reorders: true, nests: false)

    static func kindSymbol(_ kind: PhotoLayerKind) -> String {
        if case .adjustment = kind { return "slider.horizontal.3" }
        return "photo"
    }

    static func kindLabel(_ kind: PhotoLayerKind) -> String { kind.label }

    static func eyeIdentifier(_ id: PhotoLayer.ID) -> String { "photo.layer.\(id).eye" }
    static func kindIdentifier(_ id: PhotoLayer.ID) -> String { "photo.layer.\(id).kind" }
}
