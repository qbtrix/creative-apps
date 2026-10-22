// HaloWindow.swift: Halo's window and command router. It is SuiteWindow with
// the project's compositions in the sidebar, HaloViewer as content and
// HaloCompositionInspector (settings and layers) in the inspector, a column
// `inspectorWidth` wide whatever it shows. Every
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
// focused value and its project as `haloProject` (the menus read titles and
// availability from it), opens on HaloLaunch's project and, under
// `-HaloControlsProbe`, publishes the `halo.controls` JSON
// (HaloControls.swift). A viewer drag or inspector scrub shows through its
// `live` HaloLiveEdit and reaches `perform` once, at its end. The toolbar's New Composition… is `halo.composition.new`. Views only read HaloProject and call its methods; all
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
    /// The drag in progress, which the viewer draws without re-running this body (HaloLiveEdit.swift).
    @State var live = HaloLiveEdit()
    /// The viewer's shape tool: on, its drag's draft, and its draw (HaloShapeTool.swift).
    @State var shapes = HaloShapeDrawing()

    /// The inspector column: the token's ideal as its minimum and ideal, so
    /// its width never follows its content (#4313) and the TEXT color row
    /// keeps its "Color" label (#4314; at the 200 pt minimum it showed a
    /// sliver of the C). The window's minimum and launch widths are unchanged.
    static let inspectorWidth = SuiteSize.inspectorWidth.ideal

    #if DEBUG
    /// How many times a window's body ran; HaloWindowPlaybackTests counts playback's.
    static var bodyRuns = 0
    /// The project the last body ran on, for the hosted-window tests to read back.
    static var shownProject: HaloProject?
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        let _ = Self.shownProject = model
        #endif
        let newComposition = ToolbarAction("New Composition…", systemImage: "plus", identifier: "halo.composition.new") {
            perform(.newComposition)
        }
        scenes(
            SuiteWindow(title: fileWindowTitle, actions: [newComposition], inspectorWidth: Self.inspectorWidth) {
                SuiteSidebarList(
                    sections: [SidebarSection(
                        id: "compositions", title: "Compositions",
                        items: model.compositions.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "rectangle.stack") },
                        addAction: newComposition)],
                    selection: model.selectedCompositionID,
                    onSelect: { perform(.selectComposition($0)) },
                    onRename: { perform(.renameComposition($0, $1)) })
            } content: {
                HaloViewer(model: model, perform: perform, onShapeIntent: { intent in
                    shapes.isOn = true
                    takePlayback()
                    model.runShape(intent)
                })
            } inspector: {
                Group {
                    if model.selectedComposition != nil {
                        HaloCompositionInspector(model: model, perform: perform, runFill: {
                            takePlayback()
                            model.runFill($0)
                        })
                    } else {
                        EmptyStateView(
                            "No Selection", systemImage: "rectangle.stack", message: "Select a composition to see its settings.")
                    }
                }
                // The column's width, never its content's: a keyed, eased pick widened it 5 pt (#4313).
                .frame(minWidth: .zero, idealWidth: Self.inspectorWidth - 2 * SuiteSpacing.m, maxWidth: .infinity, alignment: .top)
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
        .environment(\.haloLiveEdit, live)
        .onAppear { live.current = { model } }
        .focusedSceneValue(\.haloPerform, perform)
        .focusedSceneValue(\.haloProject, model)
        .haloControlsProbe(HaloLaunch.current.controlsProbe)
    }

    /// Does `command` through its area's file. A command its area hasn't
    /// built does nothing there; menus and controls disable it with
    /// `model.unavailableHelp(for:)` as help.
    func perform(_ command: HaloCommand) {
        if case .tick = command {} else { takePlayback() }
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
        historyScene(textScene(renderScene(easingScene(fileScene(editScene(layersScene(keysScene(playbackScene(viewerScene(content))))))))))
    }
}
