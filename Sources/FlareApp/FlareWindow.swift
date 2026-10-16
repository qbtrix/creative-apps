// FlareWindow.swift: Flare's window on SuiteWindow. The model comes from the
// launch flags (FlareLaunch: -FlareFixture, -FlareSample, -FlareOpenFile).
// The sidebar holds SCENES and LAYERS; the toolbar is New, Open, Save, Undo,
// Redo, Auto-key, Animate… and Export…, each disabled with its area's reason
// while it can't act. The content is the stage over the timeline (FlareCanvas)
// while a document is open, else the empty state with New Animation; the
// inspector is FlareInspector (Properties and Library tabs). Every control
// goes through one FlareIntent: `perform` and `help(for:)` in
// FlareWindow+Router.swift hand it to its area's file, and a control's
// accessibility identifier is its intent's `identifier`. The stubs
// (FlareTimeline, FlareRecording and the four modifiers) are filled by later
// tasks without touching their call sites here. The
// window owns presentation state only: zoom, rulers, guides, the inspector
// tab and what is presented (FlarePresentation, in FlareNewSheet.swift).
// It publishes the menu bar's FlareMenu (FlareCommands.swift): `perform` and
// `help` for every section 3.4 item, the Undo and Redo step names, the recent
// files and Loop.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareWindow: View {
    @State var model = FlareWorkspace(launch: FlareLaunch(arguments: ProcessInfo.processInfo.arguments))
    /// nil fits the stage; set once the user zooms.
    @State var zoom: Double? = nil
    @State var showsRulers = true
    @State var showsGuides = true
    @State var inspectorTab: FlareInspectorTab = .properties
    /// The new sheet, alerts and the recovery offer.
    @State var presented: FlarePresentation? = nil
    let launch = FlareLaunch(arguments: ProcessInfo.processInfo.arguments)

    #if DEBUG
    /// How many times a window's body ran; RenderBudgetFlareTests counts an interaction's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        SuiteWindow(
            title: model.document == nil ? "Flare" : model.title,
            sections: SidebarSection.flare(model, onAddLayer: { perform(.layers(.addLayer)) }),
            selection: model.selectedLayerID ?? model.selectedSceneID,
            onSelect: { perform(.layers(.select(id: $0))) },
            onToggle: { perform(.layers(.toggle(id: $0, flag: $1))) },
            onMove: { section, rows, destination in
                if let row = rows.first { perform(.layers(.move(section: section, from: row, to: destination))) }
            },
            onRename: { perform(.layers(.rename(id: $0, name: $1))) },
            actions: toolbar
        ) {
            FlareCanvas(
                model: model, zoom: zoom, showsRulers: showsRulers, showsGuides: showsGuides, perform: perform,
                help: { help(for: $0) }, tick: { model.tick(target: $0, ticker: &$1) }, onKey: toolKey)
        } inspector: {
            FlareInspector(
                model: model, tab: inspectorTab, perform: perform,
                easing: FlareEasingInspector(
                    editor: model, onSelect: { model.selectEasingSegment($0) },
                    onPreset: { model.setEasingPreset($0) }, onMoveHandle: { model.moveEasingHandle($0, to: $1) },
                    onEndDrag: { model.endEasingHandleDrag() }))
        }
        .modifier(FlareFilePanels(model: model, launch: launch, perform: perform))
        .modifier(FlareNewSheet(presented: $presented, perform: perform))
        .modifier(FlareOpenStatus(model: model))
        .modifier(FlareRecovery(model: model, restore: { model.restoreRecovery($0) }))
        .focusedSceneValue(
            \.flareMenu,
            FlareMenu(
                perform: { menuPerform($0) }, help: { menuHelp($0) },
                undoTitle: model.undoActionName ?? "Undo", redoTitle: model.redoActionName ?? "Redo",
                recent: model.recent, loops: model.loops))
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
/// open, else the empty state whose one action is New Animation (Open is the
/// toolbar's).
struct FlareCanvas: View {
    let model: FlareWorkspace
    var zoom: Double? = nil
    var showsRulers = true
    var showsGuides = true
    var perform: @MainActor (FlareIntent) -> Void = { _ in }
    var help: @MainActor (FlareIntent) -> String? = { _ in nil }
    var tick: @MainActor (Double, inout PlaybackTicker) -> Bool = { _, _ in false }
    /// The stage's keys it doesn't take itself (Return, Escape): the window's `toolKey`.
    var onKey: @MainActor (KeyPress) -> KeyPress.Result = { _ in .ignored }

    var body: some View {
        if model.document != nil {
            VStack(spacing: 0) {
                FlareStage(
                    model: model, zoom: zoom, showsRulers: showsRulers, showsGuides: showsGuides, perform: perform,
                    help: help, onKey: onKey)
                FlareTimeline(model: model, zoom: zoom, perform: perform, tick: tick)
            }
            .overlay { FlareRecording(model: model) }
        } else {
            EmptyStateView(
                "No Animation Open", systemImage: "film.stack",
                message: "Create an animation to start drawing scenes and keyframes.",
                action: ToolbarAction("New Animation", systemImage: "plus") { perform(.file(.new)) })
        }
    }
}
