// PhotoEditor.swift: what a Photo window shows, laid out on SuiteUI's
// SuiteWindow: the title (the file's name, "Untitled" for an image with none,
// else "Photo") with the save state as its subtitle, the toolbar's eight
// commands (PhotoToolbarItem: Open, Save and Export beside the title; Undo,
// Redo and the zoom commands trailing), the layer list in the sidebar
// (PhotoLayerList), the canvas with its rulers in EditorDetail with the
// floating tool palette over its leading edge while an image is open (each
// tool a PhotoPaletteTool carrying the workspace's `toolHelp`) and the status
// line under it (SuiteUI's ViewerStatusBar with the workspace's refusal, which
// the window clears after 4 s, and the save status `photo.bar.saved` beside it), and PhotoPanel in the inspector. Values in, intents out: it
// reads the workspace and sends every action to `perform`, so the same view
// draws the live window and the snapshots. A control that can't act now is
// disabled with a tooltip saying why, and a disabled tool's shortcut key does
// nothing. The canvas shows no scrollers: AppKit's scroller parts are unnamed
// buttons (the app audit's unnamed check), and a zoomed image still pans by
// scrolling.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoEditor: View {
    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not a file on disk."
    let model: PhotoWorkspace
    var tiles: CanvasTiles?
    var renderMilliseconds: Double?
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
    /// How many times an editor's body ran; PhotoWindowStrokeTests counts a stroke's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        SuiteWindow(
            title: model.documentName ?? (model.canvas == nil ? "Photo" : "Untitled"),
            // Never nil, so the split view keeps its identity when an image opens; "" shows none.
            subtitle: saveStatus?.title ?? "",
            documentActions: Self.documentItems.map { action($0) },
            actions: Self.trailingItems.map { action($0) },
            inspectorWidth: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m
        ) {
            PhotoLayerList(model: model, perform: perform)
        } content: {
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
                    // The refusal, then zoom, image size, the note, the tool, the render
                    // time and, on the fakes (`-PhotoFixture`), the "Preview data" pill.
                    ViewerStatusBar(
                        zoom: model.canvas == nil ? 0 : zoom, size: model.viewerSizeText,
                        message: model.statusMessage.map { ($0, "photo.status.message") },
                        preview: model.isPreviewData ? (Self.previewHelp, "photo.status.preview") : nil
                    ) {
                        if let note { Text(note) }
                        if model.canvas != nil { Text(model.tool.title) }
                        if let renderMilliseconds { Text("\(Int(renderMilliseconds.rounded())) ms render") }
                    }
                }
                .background(SuiteColor.panel)
            }
        } inspector: {
            PhotoPanel(model: model, perform: perform)
        }
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

/// The canvas: the rendered picture (TileCanvas) on the checkerboard with PhotoCanvasOverlay's
/// marks over it (fed the pointer's document point), or the empty state. Drags go to the active tool;
/// with the canvas focused, V M B E S J C I pick enabled tools, Delete clears the selection
/// (Shift-Delete fills it), Return sends `confirm` (apply a crop) and Escape `dismiss` (cancel it
/// or deselect). Dropping an image file opens it. While the Straighten sheet is
/// open the picture turns by its angle under StraightenMarks.
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

    var body: some View {
        Group {
            if let canvas = model.canvas {
                let size = CGSize(width: canvas.width, height: canvas.height)
                CanvasViewport(
                    documentSize: size, zoom: zoom, pointer: model.tool.pointer, onSize: onViewport, onZoom: onZoom,
                    onDrag: { perform(.drag($0, $1)) }, onDragEnd: { perform(.endDrag) }, onKey: key,
                    onPointer: { hover = $0 }
                ) {
                    if let tiles { TileCanvas(tiles: tiles, zoom: zoom, degrees: straighten?.degrees ?? 0) }
                } overlay: {
                    PhotoCanvasOverlay(model: model, zoom: zoom, hover: hover)
                    if let straighten,
                        let frame = model.straightenFrame(degrees: straighten.degrees, cropToFit: straighten.cropToFit)
                    {
                        StraightenMarks(frame: frame, cropToFit: straighten.cropToFit, zoom: zoom)
                    }
                }
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: "Open a photo, drop one here, or make a new image with File > New Image.",
                    action: ToolbarAction("Open…", systemImage: "folder") { perform(.open) })
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            perform(.openFile(url))
            return true
        }
    }

    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.subtracting(.shift).isEmpty else { return .ignored }
        switch press.key {
        case .delete, .deleteForward:
            perform(press.modifiers.contains(.shift) ? .fillSelection : .deleteSelection)
        case .return:
            perform(.confirm)
        case .escape:
            perform(.dismiss)
        default:
            // A disabled tool's key does nothing, as its palette button does.
            guard
                let tool = PhotoTool.allCases.first(where: { $0.shortcut.map(String.init) == press.characters.lowercased() }),
                model.toolHelp(tool) == nil
            else { return .ignored }
            perform(.tool(tool))
        }
        return .handled
    }
}

extension PixelRect {
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
