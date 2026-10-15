// HaloWindow.swift: Halo's window. It is SuiteWindow with the project's
// compositions in the sidebar, HaloViewer as content and
// HaloCompositionInspector (settings and layers) in the inspector. New
// Composition opens NewCompositionSheet; a double-click on a sidebar row
// renames it; a refused rename opens RenameRefusalAlert with the typed name
// kept. It publishes the Composition menu's actions and Layer > New's action
// as focused scene values. It opens on HaloLaunch's project (a fixture under
// `-HaloFixture` or `-HaloSample`) and, under `-HaloControlsProbe`, publishes
// the `halo.controls` JSON (HaloControls.swift). Views only read HaloProject
// and call its methods; all state lives in HaloModel (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

struct HaloWindow: View {
    @State private var model = HaloLaunch.project
    @State private var showsNewComposition = false

    var body: some View {
        let newComposition = ToolbarAction("New Composition…", systemImage: "plus") { showsNewComposition = true }
        SuiteWindow(
            title: model.compositions.isEmpty ? "Halo" : "Untitled Project",
            sections: [SidebarSection(
                id: "compositions", title: "Compositions",
                items: model.compositions.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "rectangle.stack") },
                addAction: newComposition)],
            selection: model.selectedCompositionID,
            onSelect: { model.selectComposition($0) },
            onRename: { id, name in _ = model.renameComposition(id, to: name) },
            actions: [newComposition]
        ) {
            HaloViewer(
                model: model, onNew: { showsNewComposition = true }, onScrub: { model.scrub(to: $0) },
                onSelectLayer: { model.selectLayer($0) }, onSetInPoint: { _ = model.setSelectedLayerInPoint() },
                onSetOutPoint: { _ = model.setSelectedLayerOutPoint() })
        } inspector: {
            if let comp = model.selectedComposition {
                HaloCompositionInspector(
                    comp: comp, selectedLayerID: model.selectedLayerID, onSelectLayer: { model.selectLayer($0) })
            } else {
                EmptyStateView("No Selection", systemImage: "rectangle.stack", message: "Select a composition to see its settings.")
            }
        }
        .sheet(isPresented: $showsNewComposition) {
            NewCompositionSheet(
                settings: model.suggestedSettings,
                onCreate: { settings in if model.newComposition(settings) { showsNewComposition = false } },
                onCancel: { showsNewComposition = false })
        }
        .modifier(RenameRefusalAlert(
            refusal: model.refusedRename,
            problem: { model.renameProblem($0.id, to: $1) },
            onRename: { _ = model.renameComposition($0.id, to: $1) },
            onDismiss: { model.dismissRefusedRename() }))
        .focusedSceneValue(\.haloCompositionActions, compositionActions)
        .focusedSceneValue(\.haloNewLayer, newLayer)
        .haloControlsProbe(HaloLaunch.current.controlsProbe)
    }

    /// The Composition menu's actions for the selected composition.
    private var compositionActions: HaloCompositionActions {
        var actions = HaloCompositionActions(new: { showsNewComposition = true })
        if let id = model.selectedCompositionID {
            actions.duplicate = { _ = model.duplicateComposition(id) }
            if model.canDeleteComposition { actions.delete = { deleteComposition(editingText: $0) } }
        }
        return actions
    }

    /// Composition > Delete: deletes the selected composition, or, while a
    /// text field such as the rename field has focus, edits its text instead.
    private func deleteComposition(editingText: Bool) {
        switch model.compositionDeleteCommand(editingText: editingText) {
        case .editText: HaloTextFocus.deleteToStartOfLine()
        case .delete(let id): _ = model.deleteComposition(id)
        case .unavailable: break
        }
    }

    /// Layer > New's action, nil when no composition is selected.
    private var newLayer: (@MainActor (HaloLayerKind) -> Void)? {
        guard model.canAddLayer else { return nil }
        return { model.newLayer($0) }
    }
}
