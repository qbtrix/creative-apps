// FlareWindow.swift: Flare's window on SuiteWindow. The model comes from the
// launch flags (FlareLaunch: -FlareFixture, -FlareSample, -FlareOpenFile).
// The sidebar is a SuiteSidebarList of SCENES over the shared LayerTreeList
// of LAYERS (FlareLayersList, FlareWindow+Layers.swift), and the
// inspector column is `inspectorWidth` wide in every state; the toolbar is New, Open, Save, Undo,
// Redo, Auto-key, Animate… and Export…, each disabled with its area's reason
// while it can't act. The content is the stage over the timeline (FlareCanvas)
// while a document is open, else the empty state with New Animation, which
// opens a .flare dropped on it in this window (FlareShell.openQueue); the
// inspector is FlareInspector (Properties and Library tabs). Every control
// goes through one FlareIntent: `perform` and `help(for:)` in
// FlareWindow+Router.swift hand it to its area's file, and a control's
// accessibility identifier is its intent's `identifier`. The stubs
// (FlareTimeline, FlareRecording and the four modifiers) are filled by later
// tasks without touching their call sites here. The
// window owns presentation state only: zoom, rulers, guides, the inspector
// tab and which setup sheet is up (FlareSetupSheet, in FlareDocumentSheet.swift),
// plus the export task and the file it last wrote (FlareWindow+Export.swift);
// the export sheet is FlareExportSheetAdapter's, shown while the Model's run
// isn't idle.
// It publishes the menu bar's FlareMenu (FlareCommands.swift): `perform` and
// `help` for every section 3.4 item, the Undo and Redo step names, Loop and
// the selection's Edit reasons, and File > Place…'s reason and action; the
// window takes SVG drops (FlarePlace.swift). The model's file flow follows the
// suite's recents (the bridge's list, the only one Open Recent reads; #5126).
import FlareModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

struct FlareWindow: View, BodyCounted {
    @State var model = FlareWorkspace(launch: FlareLaunch(arguments: ProcessInfo.processInfo.arguments))
    /// nil fits the stage; set once the user zooms.
    @State var zoom: Double? = nil
    /// The stage's fit, which Zoom In and Zoom Out step from while `zoom` is nil.
    @State var fitted = 1.0
    @State var showsRulers = true
    @State var showsGuides = true
    @State var inspectorTab: FlareInspectorTab = .properties
    /// The New and Document Settings sheet (document-setup DS-14).
    @State var presented: FlareSetupSheet? = nil
    /// The export under way, so Cancel can stop it.
    @State var exportTask: Task<Void, Never>? = nil
    /// The first file the last export wrote, for Reveal in Finder.
    @State var exportedFile: URL? = nil
    /// The process's flags; a hosted-window test passes its own, so `-FlareExportTo` reaches the export and no
    /// folder panel opens.
    var launch = FlareLaunch(arguments: ProcessInfo.processInfo.arguments)

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    /// The model the last body ran on, for the hosted-window tests to read back.
    static var shownModel: FlareWorkspace?
    /// The last body's place (FlarePlace.swift), for RenderBudgetFlarePlaceTests to send the menu's place.
    @MainActor static var placeProbe: (@MainActor ([(name: String, data: Data)]) -> Void)?
    /// The last body's `perform`, for the hosted-window tests to send intents through (FlareFileFlowLiveTests).
    @MainActor static var shownPerform: ((FlareIntent) -> Void)?
    #endif

    /// The inspector column: the editor's panel width plus SuiteWindow's
    /// gutter on each side, as Design's and Photo's, so it never jumps
    /// width between states and the easing presets' three columns read in
    /// full (#1853).
    static let inspectorWidth = SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        let _ = Self.shownModel = model
        let _ = Self.placeProbe = { _ = place($0) }
        let _ = Self.shownPerform = { perform($0) }
        #endif
        SuiteWindow(
            title: model.document == nil ? "Flare" : model.title, actions: toolbar,
            inspectorWidth: Self.inspectorWidth,
            contextActions: { FlareRowMenu.actions(model.sceneRowMenu($0), perform: { perform(.layers($0)) }) }
        ) {
            VStack(spacing: 0) {
                SuiteSidebarList(
                    sections: [SidebarSection.flareScenes(model, perform: { perform(.layers($0)) })],
                    selection: model.selectedLayerID == nil ? model.selectedSceneID : nil,
                    onSelect: { perform(.layers(.select(id: $0))) },
                    onMove: { section, rows, destination in
                        if let row = rows.first { perform(.layers(.move(section: section, from: row, to: destination))) }
                    },
                    onRename: { perform(.layers(.rename(id: $0, name: $1))) })
                FlareLayersList(model: model, perform: { perform(.layers($0)) })
            }
        } content: {
            FlareCanvas(
                model: model, zoom: zoom, showsRulers: showsRulers, showsGuides: showsGuides, perform: perform,
                help: { help(for: $0) }, tick: { model.tick(target: $0, ticker: &$1) }, onKey: toolKey,
                onFit: { fitted = $0 }, onDismissNote: { model.dismissImportNote() })
        } inspector: {
            FlareInspector(
                model: model, tab: inspectorTab, perform: perform,
                easing: FlareTimingRow(
                    editor: model, onSelect: { model.selectEasingSegment($0) },
                    onPreset: { model.setEasingPreset($0) }, onMoveHandle: { model.moveEasingHandle($0, to: $1) },
                    onEndDrag: { model.endEasingHandleDrag() }),
                shape: shapeOptions)
        }
        .modifier(FlareFilePanels(model: model, launch: launch, perform: perform))
        .modifier(FlareDocumentSheet(
            sheet: $presented, setup: model.documentSetup, limits: model.documentLimits, perform: perform,
            apply: { model.applyDocumentSetup($0, anchor: $1); return model.layerError == nil }))
        .modifier(FlareExportSheetAdapter(model: model, perform: perform))
        .modifier(FlareOpenStatus(model: model))
        .suiteOpenQueue(FlareShell.openQueue, isEmpty: model.takesOpenedFile, open: { open($0) })
        .modifier(FlareAutosaveAdapter(model: model, restore: { try model.restoreRecovery($0) }))
        .onChange(of: Self.bridge.recents(for: .flare), initial: true) { model.updateFileFlow(recents: $1) }
        .suiteLiveWindow(FlareLive.front, read: { FlareHeadless(workspace: model) }, write: { model.takeLive($0) })
        .placeDropTarget(formats: model.placeFormats) { files, _ in place(files) }
        .focusedSceneValue(
            \.flareMenu,
            FlareMenu(
                perform: { menuPerform($0) }, help: { menuHelp($0) },
                undoTitle: model.undoActionName ?? "Undo", redoTitle: model.redoActionName ?? "Redo",
                loops: model.loops, editHelps: model.editHelps,
                selectionHelps: [model.deleteHelp, model.orderHelp(forward: true), model.orderHelp(forward: false)],
                placeHelp: model.placeMenuHelp, place: { choosePlace() },
                document: model.suiteDocument, documentSettings: { presented = .settings },
                settingsHelp: model.selectedScene == nil ? "Open or create an animation first." : nil))
    }

    /// The menu bar's door: File > Open Sample > Keyed Ball opens the keyed
    /// sample (the easing journey's route); every other item goes through
    /// `perform`, the file area's samples included.
    private func menuPerform(_ intent: FlareIntent) {
        if intent == .file(.openSample(name: "keyed")) { model.newSampleAnimation() } else { perform(intent) }
    }

    /// Why a menu item can't act now: nil for Keyed Ball, else `help(for:)`.
    private func menuHelp(_ intent: FlareIntent) -> String? {
        intent == .file(.openSample(name: "keyed")) ? nil : help(for: intent)
    }

    /// The toolbar, in the captain's order: each action takes its intent's
    /// title, identifier and reason, and acts through `perform`.
    private var toolbar: [ToolbarAction] {
        let items: [(FlareIntent, String)] = [
            (.file(.new), "doc.badge.plus"), (.file(.open), "folder"), (.file(.save), "square.and.arrow.down"),
            (.edit(.undo), "arrow.uturn.backward"), (.edit(.redo), "arrow.uturn.forward"),
            (.timeline(.toggleAutoKey), "record.circle"), (.assist(.showPopover), "sparkles"),
            (.export(.showSheet), "square.and.arrow.up"),
        ]
        return items.map { intent, image in
            ToolbarAction(
                intent.toolbarTitle, systemImage: image,
                isSelected: intent == .timeline(.toggleAutoKey) && model.autoKey,
                unavailableHelp: help(for: intent), identifier: intent.identifier
            ) { perform(intent) }
        }
    }
}

/// The window's content: the stage over the timeline while a document is
/// open, under the import note after a Lottie open (FlareImportNoteAdapter.swift), else the empty state whose one action is New Animation (Open is the
/// toolbar's). New Animation is `.file(.new)` like the toolbar's New, so it
/// takes `emptyNewIdentifier` to keep `suite.controls` free of duplicates.
struct FlareCanvas: View {
    /// The empty state's New Animation: `.file(.new)`'s identifier, set apart from the toolbar's New.
    static let emptyNewIdentifier = FlareIntent.file(.new).identifier + ".empty"
    let model: FlareWorkspace
    var zoom: Double? = nil
    var showsRulers = true
    var showsGuides = true
    var perform: @MainActor (FlareIntent) -> Void = { _ in }
    var help: @MainActor (FlareIntent) -> String? = { _ in nil }
    var tick: @MainActor (Double, inout PlaybackTicker) -> Bool = { _, _ in false }
    /// The stage's keys it doesn't take itself (Return, Escape): the window's `toolKey`.
    var onKey: @MainActor (KeyPress) -> KeyPress.Result = { _ in .ignored }
    var onFit: @MainActor (Double) -> Void = { _ in }
    /// The import note's Dismiss (FlareImportNoteAdapter.swift): the window's `model.dismissImportNote()`.
    var onDismissNote: @MainActor () -> Void = {}
    /// Ticks the model while playing: started when `model.isPlaying` turns true, stopped when it turns false or
    /// the canvas leaves the screen. Its `measuredFPS` feeds the stage's status pills.
    @State private var driver: PlaybackDriver?

    var body: some View {
        if model.document != nil {
            VStack(spacing: 0) {
                FlareImportNoteAdapter(rows: model.importNoteRows, onDismiss: onDismissNote)
                FlareStage(
                    model: model, zoom: zoom, showsRulers: showsRulers, showsGuides: showsGuides, perform: perform,
                    help: help, onKey: onKey, measuredFPS: driver?.measuredFPS, onFit: onFit)
                FlareTimeline(model: model, perform: perform)
            }
            .overlay { FlareRecording(model: model) }
            .onChange(of: model.isPlaying, initial: true) { _, playing in follow(playing: playing) }
            .onDisappear { driver?.stop() }
        } else {
            EmptyStateView(
                "No Animation Open", systemImage: "square.stack.3d.forward.dottedline",
                message: "Create an animation to start drawing scenes and keyframes.",
                action: ToolbarAction("New Animation", systemImage: "plus", identifier: Self.emptyNewIdentifier) {
                    perform(.file(.new))
                },
                onDrop: { urls in
                    // A .flare dropped here opens in this window (FlareShell.openQueue), any more in new ones.
                    let files = urls.filter { FlareHeadless.openExtensions.contains($0.pathExtension.lowercased()) }
                    files.forEach(FlareShell.openQueue.open)
                    return !files.isEmpty
                })
        }
    }

    /// Runs the display link while playing and stops it otherwise.
    private func follow(playing: Bool) {
        guard playing else {
            driver?.stop()
            return
        }
        let tick = tick
        let running = driver ?? PlaybackDriver(onTick: { target, ticker in tick(target, &ticker) })
        driver = running
        running.start()
    }
}
