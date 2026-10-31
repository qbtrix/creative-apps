// HaloLayerList.swift: the selected composition's layers, top first, flush
// under the inspector's Layers section (which draws the title, so the list has
// none), as an editable list (layer-panel, #770). SuiteUI's LayerTreeList
// draws the rows (adopt-kernel-layers AL-h3) from the Model's `layerRows`,
// one level: Halo's parent link is the inspector's picker, not nesting. It
// sits embedded in the inspector's scroll view, with no eye or lock (Halo has
// neither yet), and a drop on a row reorders the dragged layer beside it.
// Ids are Halo's own (`.app` naming): the list is `halo.layer.list`, a row
// `halo.layer.row.<layer id>`, its parts `halo.layer.<layer id>.<part>`.
// Each row's decoration carries its kind's SF Symbol, its tooltip
// (HaloLayerKind.rowHelp: how to rename and reorder it) and its VoiceOver
// value naming the kind ("Solid layer"); names draw at the inspector's label
// size, like the rows above the list. A click selects (`selectLayer`); a
// double-click on the name, Return on the focused row or the Rename action
// opens the row's rename field, which sends `renameLayer(id, name)` and closes
// (the Model refuses a blank name). A drop goes out as LayerTreeList's
// LayerDrop and the Model turns it into `moveLayer`
// (`HaloProject.layerDropCommand`); the view does no index math. A refused
// rename shows its message in W0's InspectorNote (`halo.layer.refusal`) under
// the list: a row's caption can't carry that identifier. A composition with
// no layers shows "No layers yet. Add one from Layer > New."
// (`halo.layer.empty`). The list takes focus, so Delete (⌫) there sends
// `deleteLayer` (in the viewer and timeline ⌫ deletes the picked keys first,
// HaloViewer). Under the rows sits SuiteUI's LayerActionBar: New Layer (a
// solid), Duplicate, Delete and fx (waiting on layer styles), each
// `halo.layer.bar.<part>`; a row's context menu holds Rename…, Duplicate,
// Delete, Bring Forward and Send Backward. Every item is the Layer menu's own
// (`ToolbarAction(spec, on:)` on HaloMenuTarget's state, the spec and title
// HaloMenuTarget.item uses), so title, enablement and reason
// match it; a row's menu reads the project with that row selected, and a pick
// selects the row first. Values in, commands out. The list sits in the inspector's
// scroll view, so under `-SuitePerfProbe` each move of its top in that scroll
// view records a `layers-scroll` frame (HaloProbe).
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerList: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    @Environment(\.suiteProbeRecorder) private var recorder

    /// Halo's ids for the shared list, kept from the hand-rolled rows so the journeys still find them.
    static let naming = LayerTreeNaming.app(
        LayerTreeIDs(container: "halo.layer.list", row: "halo.layer.row.", control: "halo.layer."))
    static let options = LayerTreeOptions(showsEye: false, showsLock: false, reorders: true, embedded: true, nests: false)

    var body: some View {
        let layers = model.selectedComposition?.layers ?? []
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            if layers.isEmpty {
                Label("No layers yet. Add one from Layer > New.", systemImage: "square.stack.3d.up")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .padding(.horizontal, SuiteSpacing.m)
                    .frame(minHeight: SuiteSize.studioRow, alignment: .leading)
                    .accessibilityIdentifier("halo.layer.empty")
            } else {
                LayerTreeList(
                    rows: model.layerRows, childCount: { _ in 0 }, selection: model.selectedLayerID,
                    naming: Self.naming, options: Self.options, decorations: Self.decorations(layers),
                    onSelect: { perform(.selectLayer($0)) },
                    onRename: { id, name in
                        perform(.renameLayer(id, name))
                        return nil
                    },
                    contextActions: { Self.rowMenu(target, row: $0) },
                    onAction: act)
                // Names at the inspector's label size, as the Parent and Blend rows above.
                .font(SuiteFont.inspectorLabel)
            }
            LayerActionBar(Self.bar(target))
            if let refusal = rowRefusal(in: layers) {
                InspectorNote(refusal.message, kind: .error, identifier: "halo.refusal")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("halo.layer.refusal")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: Double.self) { Double($0.frame(in: .scrollView(axis: .vertical)).minY) } action: { _ in
            HaloProbe(recorder).drew(HaloProbe.layersScroll)
        }
        .focusable()
        .focusEffectDisabled()
        .onDeleteCommand { perform(.deleteLayer) }
    }

    /// The Layer menu's target over this list's project.
    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    /// The bar's commands with their symbols and id parts; New adds a solid, the Layer menu's first kind.
    nonisolated static let barCommands: [(command: HaloCommand, symbol: String, part: String)] = [
        (.newLayer(.solid), "plus", "new"), (.duplicateLayer, "plus.square.on.square", "duplicate"),
        (.deleteLayer, "trash", "delete"),
    ]

    /// A row menu's commands with their symbols.
    nonisolated static let rowCommands: [(command: HaloCommand, symbol: String)] = [
        (.beginRenameLayer, "pencil"), (.duplicateLayer, "plus.square.on.square"), (.deleteLayer, "trash"),
        (.bringLayerForward, "square.2.layers.3d.top.filled"), (.sendLayerBackward, "square.2.layers.3d.bottom.filled"),
    ]

    /// The bar: each command as its Layer menu item, then fx, disabled until layer styles land.
    // view-static: main-actor
    static func bar(_ target: HaloMenuTarget) -> [ToolbarAction] {
        barCommands.map { entry in
            let title = entry.command == .newLayer(.solid) ? "New Layer" : nil
            return action(target, entry.command, title: title, systemImage: entry.symbol,
                          identifier: "halo.layer.bar." + entry.part)
        } + [LayerActionBar.effects(identifier: "halo.layer.bar.fx")]
    }

    /// Row `id`'s context menu: each item as the Layer menu shows it with that row selected; a pick selects it first.
    // view-static: main-actor
    static func rowMenu(_ target: HaloMenuTarget, row id: String) -> [ToolbarAction] {
        var model = target.model
        model?.selectLayer(id)
        let row = HaloMenuTarget(model: model) { command in
            target.perform?(.selectLayer(id))
            target.perform?(command)
        }
        return rowCommands.map { action(row, $0.command, systemImage: $0.symbol) }
    }

    /// `command` from its catalog spec on `target`'s state, titled as the Layer menu titles it.
    // view-static: main-actor
    private static func action(_ target: HaloMenuTarget, _ command: HaloCommand, title: String? = nil,
                               systemImage: String, identifier: String? = nil) -> ToolbarAction {
        ToolbarAction(HaloMenuState.spec(command.commandID), on: target.state, title: title ?? target.title(for: command),
                      systemImage: systemImage, identifier: identifier) { target.perform?(command) }
    }

    /// Each row's kind symbol, tooltip and VoiceOver value, by layer id.
    nonisolated static func decorations(_ layers: [HaloLayer]) -> [String: LayerRowDecoration] {
        Dictionary(layers.map { layer in
            (layer.id, LayerRowDecoration(
                symbol: layer.kind.systemImage, symbolLabel: layer.kind.layerTitle,
                help: layer.kind.rowHelp, value: layer.kind.layerTitle))
        }, uniquingKeysWith: { first, _ in first })
    }

    /// A drop sends the Model's move for it; the list has no other action without eye, lock or containers.
    private func act(_ action: LayerTreeAction) {
        guard case .move(let drop) = action,
              let command = model.layerDropCommand(drop.id, into: drop.parentID, at: drop.index) else { return }
        perform(command)
    }

    /// The refusal a layer row's control names, shown under the list.
    private func rowRefusal(in layers: [HaloLayer]) -> HaloRefusal? {
        guard let refusal = model.refusal,
              layers.contains(where: { refusal.control == "halo.layer.row.\($0.id)" }) else { return nil }
        return refusal
    }
}
