// HaloWindow.swift: Halo's window and command router. It is SuiteWindow with
// the project's compositions in the sidebar, HaloViewer as content and
// HaloCompositionInspector (settings and layers) in the inspector. Every
// action a view, a menu or a key takes is a HaloCommand sent to
// `perform(_:)`, which routes it by area to one HaloWindow+<Area>.swift file
// (composition to +Viewer, history to +Edit, files to +File, the rest to the
// file of their name); a feature fills its own area file and never this one.
// Each area file also has a `<area>Scene(_:)` hook, applied here in a fixed
// order, where it attaches its sheets, alerts, importers and launch tasks.
// A dialog an area's route asks for is the one `request`; that area's hook
// presents it and sets it back to nil. New Composition opens
// NewCompositionSheet; a refused rename opens RenameRefusalAlert with the
// typed name kept. The window publishes `perform` as the `haloPerform`
// focused value (and, until the menus move to it, the Composition menu's
// actions and Layer > New's action), opens on HaloLaunch's project and, under
// `-HaloControlsProbe`, publishes the `halo.controls` JSON
// (HaloControls.swift). Views only read HaloProject and call its methods; all
// state lives in HaloModel (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

extension FocusedValues {
    /// Sends a command to the focused Halo window; nil with no Halo window.
    @Entry var haloPerform: (@MainActor (HaloCommand) -> Void)?
}

struct HaloWindow: View {
    @State var model = HaloLaunch.project
    @State var showsNewComposition = false
    /// The dialog an area's route asked for; its area's hook shows it and sets it back to nil.
    @State var request: HaloWindowRequest?

    var body: some View {
        let newComposition = ToolbarAction("New Composition…", systemImage: "plus") { perform(.newComposition) }
        scenes(
            SuiteWindow(
                title: fileWindowTitle,
                sections: [SidebarSection(
                    id: "compositions", title: "Compositions",
                    items: model.compositions.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "rectangle.stack") },
                    addAction: newComposition)],
                selection: model.selectedCompositionID,
                onSelect: { perform(.selectComposition($0)) },
                onRename: { perform(.renameComposition($0, $1)) },
                actions: [newComposition]
            ) {
                HaloViewer(model: model, perform: perform)
            } inspector: {
                if let comp = model.selectedComposition {
                    HaloCompositionInspector(
                        comp: comp, selectedLayerID: model.selectedLayerID, onSelectLayer: { perform(.selectLayer($0)) })
                } else {
                    EmptyStateView(
                        "No Selection", systemImage: "rectangle.stack", message: "Select a composition to see its settings.")
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
                onRename: { perform(.renameComposition($0.id, $1)) },
                onDismiss: { model.dismissRefusedRename() })))
        .focusedSceneValue(\.haloPerform, perform)
        .focusedSceneValue(\.haloCompositionActions, compositionActions)
        .focusedSceneValue(\.haloNewLayer, newLayer)
        .haloControlsProbe(HaloLaunch.current.controlsProbe)
    }

    /// Does `command` through its area's file. A command its area hasn't
    /// built does nothing there; menus and controls disable it with
    /// `model.unavailableHelp(for:)` as help.
    func perform(_ command: HaloCommand) {
        switch command.area {
        case .composition: viewerPerform(command)
        case .playback: playbackPerform(command)
        case .keys: keysPerform(command)
        case .layers: layersPerform(command)
        case .history: editPerform(command)
        case .files: filePerform(command)
        case .easing: easingPerform(command)
        case .render: renderPerform(command)
        case .text: textPerform(command)
        }
    }

    /// Every area's hook over `content`, in a fixed order.
    private func scenes(_ content: some View) -> some View {
        textScene(renderScene(easingScene(fileScene(editScene(layersScene(keysScene(playbackScene(viewerScene(content)))))))))
    }

    /// The Composition menu's actions, through `perform`.
    private var compositionActions: HaloCompositionActions {
        var actions = HaloCompositionActions(new: { perform(.newComposition) })
        if model.selectedCompositionID != nil {
            actions.duplicate = { perform(.duplicateComposition) }
            if model.canDeleteComposition { actions.delete = { _ in perform(.deleteComposition) } }
        }
        return actions
    }

    /// Layer > New's action through `perform`, nil when no composition is selected.
    private var newLayer: (@MainActor (HaloLayerKind) -> Void)? {
        guard model.canAddLayer else { return nil }
        return { perform(.newLayer($0)) }
    }
}
