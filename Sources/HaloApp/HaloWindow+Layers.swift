// HaloWindow+Layers.swift: the layers area's routes and hook. Every Layer
// command calls its HaloModel method (HaloLayerEdits.swift), which refuses
// what it can't do; ⌫ from the viewer and timeline arrives as .deleteLayer.
// Rename… asks for the Rename Layer prompt through `request`
// (.renameLayer(id)); `layersScene(_:)` shows it as a system alert with a
// field holding the layer's name, sends Rename's draft as .renameLayer(id,
// name) and clears `request` on Rename or Cancel. A blank name is the Model's
// refusal, shown under the layer's row. Clearing the selection has no Model
// method yet, so it does nothing (its availability says why). The hook also
// publishes the Layer menu's reasons as the hidden `halo.menu.reasons`
// readout (HaloReadout.swift), since XCUITest reads a menu item's help tag
// as no text.
import HaloModel
import SwiftUI

extension HaloWindow {
    func layersPerform(_ command: HaloCommand) {
        switch command {
        case .newLayer(let kind): model.newLayer(kind)
        case .selectLayer(.some(let id)): model.selectLayer(id)
        case .duplicateLayer: model.duplicateSelectedLayer()
        case .deleteLayer: model.deleteSelectedLayer()
        case .bringLayerForward: model.bringSelectedLayerForward()
        case .sendLayerBackward: model.sendSelectedLayerBackward()
        case .renameLayer(let id, let name): model.renameLayer(id, to: name)
        case .moveLayer(let id, let index): model.moveLayer(id, to: index)
        case .beginRenameLayer:
            if let id = model.selectedLayer?.id { request = .renameLayer(id) }
        default: break
        }
    }

    func layersScene(_ content: some View) -> some View {
        content
            .background(alignment: .topLeading) {
                HaloReadoutElement(identifier: "halo.menu.reasons", text: model.layerMenuReasons)
            }
            .modifier(RenameLayerPrompt(
                layerID: renamingLayerID,
                name: { id in model.selectedComposition?.layers.first(where: { $0.id == id })?.name ?? "" },
                onRename: { id, name in
                    request = nil
                    perform(.renameLayer(id, name))
                },
                onDismiss: { if renamingLayerID != nil { request = nil } }))
    }

    /// The layer the Rename Layer prompt is for, while `request` asks for it.
    private var renamingLayerID: String? {
        if case .renameLayer(let id) = request { return id }
        return nil
    }
}

/// Layer > Rename…'s prompt for `layerID`; it owns only the field's draft.
private struct RenameLayerPrompt: ViewModifier {
    let layerID: String?
    let name: @MainActor (String) -> String
    let onRename: @MainActor (String, String) -> Void
    let onDismiss: @MainActor () -> Void
    @State private var draft: String?

    func body(content: Content) -> some View {
        content
            .alert(
                "Rename Layer",
                isPresented: Binding(get: { layerID != nil }, set: { if !$0 { onDismiss() } }),
                presenting: layerID
            ) { id in
                TextField("Name", text: Binding(get: { draft ?? name(id) }, set: { draft = $0 }))
                Button("Rename") { onRename(id, draft ?? name(id)) }
                    .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) { onDismiss() }
            }
            .onChange(of: layerID) { _, _ in draft = nil }
    }
}
