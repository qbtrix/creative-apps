// FlareWindow.swift: Flare's window on SuiteWindow. The model comes from the
// launch flags (FlareLaunch: -FlareFixture, -FlareSample, -FlareOpenFile).
// The sidebar holds SCENES and LAYERS; the toolbar is New, Open, Save, Undo,
// Redo, Auto-key, Animate… and Export…, each disabled with its area's reason
// while it can't act. The content is the stage over the timeline (FlareCanvas)
// while a document is open, else the empty state with New Animation; the
// inspector is FlareInspector (Properties and Library tabs). Every control
// goes through one FlareIntent: `perform` and `help` below route the few that
// act today, until DK-7 moves them into FlareWindow+Router.swift and its area
// files. The stubs (FlareTimeline, FlareRecording and the four modifiers)
// are filled by later tasks without touching their call sites here. The
// window owns presentation state only: zoom, rulers, guides, the inspector
// tab and what is presented (FlarePresentation, in FlareNewSheet.swift).
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
            sections: SidebarSection.flare(model, onAddLayer: { model.addLayer() }),
            selection: model.selectedLayerID ?? model.selectedSceneID,
            onSelect: { model.selectItem($0) },
            onToggle: { id, toggle in
                if let flag = FlareLayerFlag(rawValue: toggle) { model.toggleLayerFlag(id, flag) }
            },
            onMove: { section, rows, destination in
                // The sidebar selects one row at a time, so a drag moves one layer.
                if section == "layers", let row = rows.first { model.moveLayer(from: row, to: destination) }
            },
            onRename: { id, name in model.renameLayer(id, to: name) },
            actions: toolbar
        ) {
            FlareCanvas(
                model: model, zoom: zoom, showsRulers: showsRulers, showsGuides: showsGuides, perform: perform,
                help: { help(for: $0) }, tick: { model.tick(target: $0, ticker: &$1) })
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
                model: model, newSample: { model.newSampleAnimation() }, undo: { model.undo() },
                redo: { model.redo() }))
    }

    /// The toolbar, in the captain's order.
    private var toolbar: [ToolbarAction] {
        let items: [(FlareIntent, String, String)] = [
            (.file(.new), "New", "doc.badge.plus"), (.file(.open), "Open", "folder"),
            (.file(.save), "Save", "square.and.arrow.down"), (.edit(.undo), "Undo", "arrow.uturn.backward"),
            (.edit(.redo), "Redo", "arrow.uturn.forward"), (.timeline(.toggleAutoKey), "Auto-key", "record.circle"),
            (.assist(.showPopover), "Animate…", "sparkles"), (.export(.showSheet), "Export…", "square.and.arrow.up"),
        ]
        return items.map { intent, title, image in
            ToolbarAction(
                title, systemImage: image, isSelected: intent == .timeline(.toggleAutoKey) && model.autoKey,
                unavailableHelp: help(for: intent)
            ) { perform(intent) }
        }
    }

    /// Acts on `intent`; DK-7's router replaces this with one function per area.
    func perform(_ intent: FlareIntent) {
        switch intent {
        case .file(.new): model.newDocument()
        case .edit(.undo): model.undo()
        case .edit(.redo): model.redo()
        case .timeline(.toggleAutoKey): model.toggleAutoKey()
        case .tools(.choose(let tool)): model.selectTool(tool)
        case .inspector(.showTab(let id)): if let tab = FlareInspectorTab(rawValue: id) { inspectorTab = tab }
        default: break
        }
    }

    /// Why `intent` can't act now; nil when it can.
    func help(for intent: FlareIntent) -> String? {
        switch intent {
        case .file(.new): nil
        case .file: "Not built yet (F17a)."
        case .edit(.undo): model.canUndo ? nil : "Nothing to undo."
        case .edit(.redo): model.canRedo ? nil : "Nothing to redo."
        case .timeline(.toggleAutoKey): model.document == nil ? "Open an animation to key it." : nil
        case .tools(.choose(let tool)): model.toolHelp(tool)
        case .inspector(.showTab): nil
        case .export: "Not built yet (F15a)."
        case .assist: "Not built yet (F16a)."
        default: "Not built yet."
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

    var body: some View {
        if model.document != nil {
            VStack(spacing: 0) {
                FlareStage(
                    model: model, zoom: zoom, showsRulers: showsRulers, showsGuides: showsGuides, perform: perform,
                    help: help)
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
