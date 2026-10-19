// PhotoLayerList.swift: Photo's layer list on SuiteUI's LayerTreeList (AL-p3):
// the stack top first, each row with its eye, kind symbol and caption (info
// line, blend summary), a drop reordering through `layerListMove`; under it a
// SuiteUI SidebarActionRow of New Layer, Delete Layer and Rename Layer…
// (`photo.layer.new`, `.delete`, `.rename`). Delete is disabled on the last
// layer and says why. Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The layer rows, then the row of layer commands.
struct PhotoLayerList: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LayerTreeList(
                rows: model.layerRows, childCount: { _ in 0 }, selection: model.selectedLayerID,
                naming: PhotoLayerRow.naming, options: PhotoLayerRow.options,
                decorations: Self.decorations(model), onSelect: { perform(.selectLayer($0)) }
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
            SidebarActionRow(Self.commands(model, perform))
                .padding(.horizontal, SuiteSpacing.xs)
        }
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

    /// New Layer, Delete Layer (disabled on the last layer) and Rename Layer….
    static func commands(_ model: PhotoWorkspace, _ perform: @escaping PhotoPerform) -> [ToolbarAction] {
        [
            ToolbarAction("New Layer", systemImage: "plus", identifier: "photo.layer.new") { perform(.addLayer) },
            ToolbarAction(
                "Delete Layer", systemImage: "trash",
                unavailableHelp: model.canDeleteSelectedLayer ? nil : "The last layer can't be deleted.",
                identifier: "photo.layer.delete"
            ) { perform(.deleteLayer) },
            ToolbarAction("Rename Layer…", systemImage: "pencil", identifier: "photo.layer.rename") { perform(.renameLayer) },
        ]
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
