// PhotoLayerList.swift: Photo's layer list on SuiteUI's LayerTreeList (AL-p3):
// the stack top first, each row with its eye, kind symbol and caption (info
// line, blend summary), a drop reordering through `layerListMove`. Under it
// SuiteUI's LayerActionBar: New Layer, Duplicate Layer, Delete Layer, fx
// (waiting on layer styles), Lock/Unlock, Show/Hide Layer and Rename Layer…
// (`photo.layer.new`, `.duplicate`, `.delete`, `.fx`, `.lock`, `.visibility`,
// `.rename`). Each row shows its eye and lock. A row's context menu holds
// Rename, Duplicate, Delete, Merge Down, Flatten Image, Bring Forward, Send
// Backward, Lock/Unlock and Show/Hide. Every item is built from the Layer
// menu's catalog spec on the same state, `ToolbarAction(spec, on:)` titled as
// the menu titles it, so its title,
// enablement and reason are the menu's; a row's menu reads the workspace with
// that row selected, and a pick selects the row, then runs. A pixel layer's
// row shows its preview (`layerPreview`, #3288) in place of the kind symbol;
// the panel keeps them in its own state and asks again when the workspace's
// revision moves with no drag under way, so a stroke refreshes them once, when
// it commits. Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The layer rows, then the row of layer commands.
struct PhotoLayerList: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// Each pixel layer's preview, by id; the panel's own, refreshed on `previewKey`.
    @State private var previews: [PhotoLayer.ID: Image] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LayerTreeList(
                rows: model.layerRows, childCount: { _ in 0 }, selection: model.selectedLayerID,
                naming: PhotoLayerRow.naming, options: PhotoLayerRow.options,
                decorations: Self.decorations(model, previews: previews), onSelect: { perform(.selectLayer($0)) },
                contextActions: { Self.rowMenu(menu, row: $0) }
            ) { action in
                switch action {
                case .toggleHidden(let id): perform(.toggleVisibility(id))
                case .move(let drop):
                    if let move = model.layerListMove(drop.id, parent: drop.parentID, index: drop.index) {
                        perform(.moveLayers(IndexSet(integer: move.offset), move.destination))
                    }
                case .toggleLocked(let id): perform(.toggleLock(id))
                case .disclose: break
                }
            }
            LayerActionBar(Self.bar(menu))
        }
        .onChange(of: Self.previewKey(model), initial: true) { previews = Self.previews(model) }
    }

    /// When the previews are read again: each new revision, held while a drag is under way.
    nonisolated static func previewKey(_ model: PhotoWorkspace) -> Int { model.isDragging ? -1 : model.revision }

    /// Each pixel layer's preview, 24 points on its longer side at 2x.
    nonisolated static func previews(_ model: PhotoWorkspace) -> [PhotoLayer.ID: Image] {
        var images: [PhotoLayer.ID: Image] = [:]
        for layer in model.layers {
            guard let small = model.layerPreview(layer.id, longestSide: 48),
                  let image = CanvasRenderer.image(rgba8: small.rgba8, width: small.width, height: small.height, alpha: .last)
            else { continue }
            images[layer.id] = Image(decorative: image, scale: 2)
        }
        return images
    }

    /// The Layer menu's target over this panel's workspace.
    private var menu: PhotoMenu { PhotoMenu(model: model, perform: perform) }

    /// Each layer's preview (from `previews`) or kind symbol, and caption, by id; help names blend and opacity.
    nonisolated static func decorations(_ model: PhotoWorkspace, previews: [PhotoLayer.ID: Image] = [:])
        -> [String: LayerRowDecoration]
    {
        Dictionary(model.layers.map { layer -> (String, LayerRowDecoration) in
            let blend = model.layerBlendSummary(layer.id)
            return (layer.id, LayerRowDecoration(
                thumbnail: previews[layer.id], symbol: PhotoLayerRow.kindSymbol(layer.kind), symbolLabel: PhotoLayerRow.kindLabel(layer.kind),
                symbolID: PhotoLayerRow.kindIdentifier(layer.id), caption: model.layerCaption(layer.id),
                help: blend?.help, value: blend?.help))
        }) { first, _ in first }
    }

    /// One panel command: its catalog id, its id suffix after `photo.layer.`, and its intent.
    typealias Command = (id: String, part: String, intent: PhotoIntent?)

    /// The bar's commands, then fx after the third.
    nonisolated static func barCommands(selected: PhotoLayer.ID?) -> [Command] {
        [("layer.new", "new", .addLayer), ("layer.duplicate", "duplicate", .edit(.duplicateLayer)),
         ("layer.delete", "delete", .deleteLayer), ("layer.toggle-lock", "lock", selected.map(PhotoIntent.toggleLock)),
         ("layer.toggle-visibility", "visibility", selected.map(PhotoIntent.toggleVisibility)),
         ("layer.rename", "rename", .renameLayer)]
    }

    /// The row menu's commands for the layer `row`.
    nonisolated static func rowCommands(row: PhotoLayer.ID) -> [Command] {
        [("layer.rename", "rename", .renameLayer), ("layer.duplicate", "duplicate", .edit(.duplicateLayer)),
         ("layer.delete", "delete", .deleteLayer), ("layer.merge-down", "merge-down", .edit(.mergeDown)),
         ("layer.flatten", "flatten", .edit(.flattenImage)), ("layer.bring-forward", "bring-forward", .bringForward),
         ("layer.send-backward", "send-backward", .sendBackward), ("layer.toggle-lock", "lock", .toggleLock(row)),
         ("layer.toggle-visibility", "visibility", .toggleVisibility(row))]
    }

    /// The bar: each command as its Layer menu item on the selection, fx disabled until layer styles land.
    // view-static: main-actor
    static func bar(_ menu: PhotoMenu) -> [ToolbarAction] {
        var actions = barCommands(selected: menu.selectedLayer).map { action(menu, $0, in: menu.state()) }
        actions.insert(LayerActionBar.effects(identifier: "photo.layer.fx"), at: 3)
        return actions
    }

    /// Row `id`'s context menu: each item as the Layer menu shows it with that row selected; a pick selects it first.
    // view-static: main-actor
    static func rowMenu(_ menu: PhotoMenu, row id: PhotoLayer.ID) -> [ToolbarAction] {
        var state = menu.state()
        state.workspace.selectLayer(id)
        return rowCommands(row: id).map { action(menu, $0, in: state, selecting: id) }
    }

    /// `command` from its catalog spec on `state`, titled as the Layer menu titles it; a pick selects `selecting` first.
    // view-static: main-actor
    private static func action(_ menu: PhotoMenu, _ command: Command, in state: PhotoMenuState,
                               selecting row: PhotoLayer.ID? = nil) -> ToolbarAction {
        let title = state.title(command.id)
        return ToolbarAction(
            PhotoMenuState.spec(command.id), on: state, title: title,
            systemImage: PhotoLayerMenu.symbol(command.id, title: title), identifier: "photo.layer." + command.part
        ) {
            if let row { menu.perform(.selectLayer(row)) }
            if let intent = command.intent { menu.perform(intent) }
        }
    }
}

/// A Layers row's ids (`photo.layers`, `photo.layer.row.<id>`,
/// `photo.layer.<id>.<part>`), eye, lock, reordering, no nesting, thumbnails, and kind symbol.
enum PhotoLayerRow {
    static let naming = LayerTreeNaming.app(
        LayerTreeIDs(container: "photo.layers", row: "photo.layer.row.", control: "photo.layer."))
    static let options = LayerTreeOptions(showsEye: true, showsLock: true, reorders: true, nests: false, thumbnails: true)

    static func kindSymbol(_ kind: PhotoLayerKind) -> String {
        if case .adjustment = kind { return "slider.horizontal.3" }
        return "photo"
    }

    static func kindLabel(_ kind: PhotoLayerKind) -> String { kind.label }

    static func eyeIdentifier(_ id: PhotoLayer.ID) -> String { "photo.layer.\(id).eye" }
    static func kindIdentifier(_ id: PhotoLayer.ID) -> String { "photo.layer.\(id).kind" }
}
