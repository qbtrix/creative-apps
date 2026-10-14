// HaloApp.swift: Halo, the motion graphics app. The window is SuiteWindow
// with the project's compositions in the sidebar, HaloViewer as content and
// HaloCompositionInspector (settings and layers) in the inspector; the
// viewer's timeline strip scrubs the playhead and sets in and out points. New
// Composition opens NewCompositionSheet; a double-click on a sidebar row
// renames it; a refused rename opens RenameRefusalAlert with the typed name
// kept. The Composition menu (HaloCompositionCommands) and Layer > New
// (HaloCommands) reach the window through focused scene values. Views only
// read HaloProject and call its methods; all state lives in HaloModel
// (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

@main
struct HaloApp: App {
    var body: some Scene {
        WindowGroup { HaloWindow() }
            .commands {
                HaloCompositionCommands()
                HaloCommands()
            }
    }
}

struct HaloWindow: View {
    @State private var model = HaloProject()
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

/// The main content: the composition viewer over a status bar of its zoom,
/// size, playhead timecode and layer count, then the timeline strip
/// (HaloTimelineView), or the empty state.
struct HaloViewer: View {
    let model: HaloProject
    var onNew: @MainActor () -> Void = {}
    var onScrub: @MainActor (Int) -> Void = { _ in }
    var onSelectLayer: @MainActor (HaloLayer.ID) -> Void = { _ in }
    var onSetInPoint: @MainActor () -> Void = {}
    var onSetOutPoint: @MainActor () -> Void = {}
    /// The viewer's size, for the zoom CanvasSurface fits the artboard at.
    @State private var viewport = CGSize.zero

    var body: some View {
        if let comp = model.selectedComposition {
            let artboard = CGSize(width: comp.width, height: comp.height)
            VStack(spacing: 0) {
                CanvasSurface(artboard: artboard)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { viewport = $0 }
                ViewerStatusBar(zoom: ViewerZoom.fitScale(artboard: artboard, in: viewport), size: comp.sizeText) {
                    Text(comp.statusTimecode)
                    Text(comp.layerSummary)
                }
                Divider()
                HaloTimelineView(
                    composition: comp, rows: model.timelineRows, onScrub: onScrub, onSelectLayer: onSelectLayer,
                    onSetInPoint: onSetInPoint, onSetOutPoint: onSetOutPoint)
            }
        } else {
            EmptyStateView(
                "No Composition", systemImage: "sparkles.rectangle.stack",
                message: "Create a composition to layer and animate footage, shapes and text.",
                action: ToolbarAction("New Composition…", systemImage: "plus", perform: onNew))
        }
    }
}
