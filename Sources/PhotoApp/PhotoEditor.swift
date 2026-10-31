// PhotoEditor.swift: what a Photo window shows, laid out on SuiteUI's
// SuiteWindow: the title (the file's name, "Untitled" for an image with none,
// else "Photo") with the save state as its subtitle, the toolbar's eight
// commands (PhotoToolbarItem: Open, Save and Export beside the title; Undo,
// Redo and the zoom commands trailing), the sidebar's Layers and AI tabs
// (PhotoSidebarTabs), the canvas with its rulers in EditorDetail with the
// floating tool palette over its leading edge while an image is open (each
// tool a PhotoPaletteTool carrying the workspace's `toolHelp`) and the status
// line under it (PhotoStatusLine, with the save status `photo.bar.saved`
// beside it), all in PhotoEditorDetail, and PhotoPanel in the inspector. Values in, intents out: it
// reads the workspace and sends every action to `perform`, so the same view
// draws the live window and the snapshots. A control that can't act now is
// disabled with a tooltip saying why, and a disabled tool's shortcut key does
// nothing. The canvas shows no scrollers: AppKit's scroller parts are unnamed
// buttons (the app audit's unnamed check), and a zoomed image still pans by
// scrolling. A file dropped anywhere on the window follows the suite's drop
// rule (file-flow PF-2, `suiteFileDrop`): an image on an open one places as a
// layer in one Place step, centred; with none open it opens; another app's
// file goes to that app; the mark at the bottom says which before the drop.
// With the Pen, PhotoPenOverlay puts SuiteUI's PathEditOverlay over the canvas.
// In debug builds its body runs report to SuiteUI's BodyTally, and `bodyRuns`
// reads the running test's windows only, so a budget test that runs alongside
// suites drawing their own Photo windows counts only its own. The inspector, layer list, status line and canvas overlay read
// the window's PhotoSession facets themselves, so an option step that moves no
// facet the window reads never re-runs this body.
import PhotoModel
import SuiteShell
import SuiteUI
import SwiftUI

struct PhotoEditor: View, BodyCounted {
    let model: PhotoWorkspace
    var tiles: CanvasTiles?
    var renderMilliseconds: Double?
    /// The backend that drew the picture (CanvasRenderer.backend), for the status line.
    var renderBackend: String?
    var note: String?
    var zoom = 1.0
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }
    /// The Straighten sheet's choices while it is open, previewed on the canvas.
    var straighten: StraightenDraft?
    /// The window's save status from PhotoFileArea; nil with no image or outside a window.
    @Environment(\.photoSaveStatus) private var saveStatus

    /// The commands beside the title, then the trailing ones, in toolbar order.
    private static let documentItems: [PhotoToolbarItem] = [.open, .save, .export]
    private static let trailingItems: [PhotoToolbarItem] = [.undo, .redo, .zoomOut, .fit, .zoomIn]

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        SuiteWindow(
            title: model.documentName ?? (model.canvas == nil ? "Photo" : "Untitled"),
            // Never nil, so the split view keeps its identity when an image opens; "" shows none.
            subtitle: saveStatus?.title ?? "",
            documentActions: Self.documentItems.map { action($0) },
            actions: Self.trailingItems.map { action($0) },
            inspectorWidth: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m
        ) {
            PhotoSidebarTabs(model: model, perform: perform)
        } content: {
            PhotoEditorDetail(
                model: model, tiles: tiles, renderMilliseconds: renderMilliseconds, renderBackend: renderBackend,
                note: note, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform,
                straighten: straighten, saveStatus: saveStatus)
        } inspector: {
            PhotoPanel(model: model, perform: perform)
        }
        .suiteFileDrop(.photo, bridge: PhotoShell.bridge, hasDocument: model.hasDocument,
                       places: model.placesExtensions, documentName: model.documentName) { perform(.place(.drop($0))) }
    }

    /// One toolbar command: the Model's title, symbol, reason and identifier, sending its intent.
    private func action(_ item: PhotoToolbarItem) -> ToolbarAction {
        let intent: PhotoIntent = switch item {
        case .open: .open
        case .save: .save
        case .export: .export(.openSheet)
        case .undo: .undo
        case .redo: .redo
        case .zoomOut: .zoomOut
        case .fit: .fit
        case .zoomIn: .zoomIn
        }
        return ToolbarAction(
            item.title(in: model), systemImage: item.systemImage, unavailableHelp: item.unavailableHelp(in: model),
            identifier: item.identifier
        ) { perform(intent) }
    }
}

/// The window's middle column: the canvas with its rulers in EditorDetail, the tool palette over its leading edge
/// while an image is open, and the status line with the save status. Its own view so a golden draws it without the
/// split view, which renders blank offscreen (PhotoFileFlowSnapshots).
struct PhotoEditorDetail: View {
    let model: PhotoWorkspace
    var tiles: CanvasTiles?
    var renderMilliseconds: Double?
    var renderBackend: String?
    var note: String?
    var zoom = 1.0
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }
    var straighten: StraightenDraft?
    var saveStatus: PhotoSaveStatus?

    var body: some View {
        EditorDetail {
            PhotoCanvas(
                model: model, tiles: tiles, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform,
                straighten: straighten)
                .scrollIndicators(.never)
        } palette: {
            if model.canvas != nil {
                ToolbarGroup(
                    tools: PhotoPaletteTool.palette(model), selected: PhotoPaletteTool(model.tool, in: model)
                ) { perform(.tool($0.tool)) }
            }
        } status: {
            HStack(spacing: 0) {
                if let saveStatus {
                    EditorSaveStatus(
                        saveStatus.editorState, title: saveStatus.title,
                        help: saveStatus.help(fileName: model.documentName), identifier: "photo.bar.saved")
                }
                PhotoStatusLine(
                    model: model, zoom: zoom, note: note, renderMilliseconds: renderMilliseconds,
                    renderBackend: renderBackend)
            }
            .background(SuiteColor.panel)
        }
    }
}

/// The canvas: the rendered picture (CanvasTiles on SuiteUI's EmbeddedCanvasHost) on the checkerboard with PhotoCanvasOverlay's
/// marks over it (fed the pointer's document point), or the empty state. Drags go to the active tool;
/// with the canvas focused, V M B E S J C I G T P pick enabled tools, Delete clears the selection
/// (Shift-Delete fills it), Return sends `confirm` (apply a crop) and Escape `dismiss` (cancel it
/// or deselect). Drops land on the whole editor (PhotoEditor's `suiteFileDrop`), not here. While the
/// Straighten sheet is open the picture turns by its angle under StraightenMarks.
struct PhotoCanvas: View {
    let model: PhotoWorkspace
    let tiles: CanvasTiles?
    let zoom: Double
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }
    var straighten: StraightenDraft?
    /// The document point under the pointer, for the brush cursor; nil once it leaves.
    @State private var hover: CGPoint?
    /// The app's View > Rendering; nil (the tile layers) in tests.
    @Environment(\.photoRendering) private var rendering
    /// The window's live drag line (LiveDragLine.swift); only the overlay reads its line.
    @Environment(\.photoDragLine) private var dragLine

    var body: some View {
        Group {
            if let canvas = model.canvas {
                let size = CGSize(width: canvas.width, height: canvas.height)
                CanvasViewport(
                    documentSize: size, zoom: zoom, pointer: model.tool.pointer, onSize: onViewport, onZoom: onZoom,
                    onDrag: { perform(.drag($0, $1)) }, onDragEnd: { perform(.endDrag) }, onKey: key,
                    onPointer: { hover = $0 }
                ) {
                    if let tiles {
                        EmbeddedCanvasHost(degrees: straighten?.degrees ?? 0, rendering: rendering?.preference) {
                            tiles.attach($0)
                        }
                    }
                } overlay: {
                    // The overlay spans the artboard at `zoom`, so a drop's point divides back to document pixels.
                    PhotoCanvasOverlay(model: model, zoom: zoom, hover: hover, perform: perform, liveLine: dragLine)
                        .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
                    if let straighten,
                        let frame = model.straightenFrame(degrees: straighten.degrees, cropToFit: straighten.cropToFit)
                    {
                        StraightenMarks(frame: frame, cropToFit: straighten.cropToFit, zoom: zoom)
                    }
                    PhotoTextBoxOverlay(model: model, zoom: zoom, perform: perform)
                        .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
                    if model.tool == .pen {
                        PhotoPenOverlay(model: model, zoom: zoom, perform: perform)
                            .frame(width: size.width * zoom, height: size.height * zoom, alignment: .topLeading)
                    }
                }
                // The viewport keeps Space for its pan before `onKey` or the box's field sees it, so the box's
                // space is typed out here, outside it (#5951: SUMMER SALE came out SUMMERSALE).
                .onKeyPress(.space) { key(" ") }
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: "Open a photo, drop one here, or make a new image with File > New Image.",
                    action: ToolbarAction("Open…", systemImage: "folder") { perform(.open) })
            }
        }
    }

    /// Types `characters` into the open Type tool box; ignored when none is open or the box doesn't take them.
    private func key(_ characters: String) -> KeyPress.Result {
        guard let typed = model.textBox?.key(characters) else { return .ignored }
        perform(.text(.key(typed)))
        return .handled
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.subtracting(.shift).isEmpty else { return .ignored }
        // While a Type tool box is open its keys type into it, not pick tools (#4798).
        if case .handled = key(press.characters) { return .handled }
        switch press.key {
        case .delete, .deleteForward:
            perform(press.modifiers.contains(.shift) ? .fillSelection : .deleteSelection)
        case .return:
            perform(.confirm)
        case .escape:
            perform(.dismiss)
        default:
            // A disabled tool's key does nothing, as its palette button does.
            // Shift cycles the tools that share the letter (Shift-J: Spot Heal, Heal, Remove).
            let current = press.modifiers.contains(.shift) ? model.tool : nil
            guard let tool = PhotoTool.picked(byTyped: press.characters, help: model.toolHelp, cyclingFrom: current)
            else { return .ignored }
            perform(.tool(tool))
        }
        return .handled
    }
}

/// The Pen over the canvas (#5072): SuiteUI's PathEditOverlay draws the draft and the path in edit and turns presses
/// and keys into the kernel's PathIntents, sent as `.path` (PhotoWorkspace.runPath runs each as its catalog command).
/// While Command is held it edits points (Direct Selection); whether it is held is the view's own state. A press is
/// held until release (#5145): a point drag moves the overlay's copy, and the window runs once, at mouse-up.
struct PhotoPenOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double
    var perform: PhotoPerform = { _ in }
    @State private var editsPoints = false
    /// Edits points without Command held: the render budget test's way in, since a scripted event can't hold a key.
    @Environment(\.photoPenEditsPoints) private var alwaysEditsPoints

    var body: some View {
        PathEditOverlay(draft: model.penDraft, path: model.pathInEdit, selection: model.anchorSelection,
                        tool: editsPoints || alwaysEditsPoints ? .directSelect : .pen, zoom: zoom) { perform(.path($0)) }
            .holdsPressesUntilRelease()
            .onModifierKeysChanged(mask: .command) { _, keys in editsPoints = keys.contains(.command) }
            .accessibilityIdentifier("photo.canvas.pen")
    }
}

extension EnvironmentValues {
    /// True: the Pen's overlay edits points as if Command were held (RenderBudgetPhotoPenAnchorTests).
    @Entry var photoPenEditsPoints = false
}

extension PixelRect {
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
