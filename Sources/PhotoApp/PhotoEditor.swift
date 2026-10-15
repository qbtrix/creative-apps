// PhotoEditor.swift: what a Photo window shows, laid out on SuiteUI's
// EditorShell: the top bar (PhotoTopBar.swift), the tool rail (each tool a
// PhotoRailTool carrying the workspace's `toolHelp`), the canvas with its
// rulers, the Adjust | Layers panel and the status line (PhotoStatusLine.swift:
// the status message, zoom, image size, the active tool, render time). Values in, intents
// out: it reads the workspace and sends every action to `perform`, so the
// same view draws the live window and the snapshots. A control that can't act
// now is disabled with a tooltip saying why, and a disabled tool's shortcut
// key does nothing. The canvas shows
// no scrollers: AppKit's scroller parts are unnamed buttons (the app audit's
// unnamed check), and a zoomed image still pans by scrolling.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoEditor: View {
    let model: PhotoWorkspace
    var tiles: CanvasTiles?
    var renderMilliseconds: Double?
    var note: String?
    var zoom = 1.0
    var tab = PhotoPanelTab.adjust
    var onTab: @MainActor (PhotoPanelTab) -> Void = { _ in }
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }
    /// The Straighten sheet's choices while it is open, previewed on the canvas.
    var straighten: StraightenDraft?

    var body: some View {
        EditorShell {
            PhotoTopBar(model: model, perform: perform)
        } rail: {
            ToolbarGroup(
                tools: PhotoRailTool.rail(model), selected: PhotoRailTool(model.tool, in: model), style: .rail
            ) { perform(.tool($0.tool)) }
        } canvas: {
            PhotoCanvas(
                model: model, tiles: tiles, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform,
                straighten: straighten)
                .scrollIndicators(.never)
        } panel: {
            PhotoPanel(model: model, tab: tab, onTab: onTab, perform: perform)
        } status: {
            PhotoStatusLine(model: model, zoom: zoom, note: note, renderMilliseconds: renderMilliseconds)
        }
    }
}

/// The Image menu's items, in the top bar and the menu bar.
struct PhotoImageMenu: View {
    let perform: PhotoPerform

    var body: some View {
        Button("Image Size…") { perform(.imageSize) }
        Divider()
        Button("Rotate 90° Clockwise") { perform(.rotate(.degrees90)) }
        Button("Rotate 90° Counterclockwise") { perform(.rotate(.degrees270)) }
        Button("Rotate 180°") { perform(.rotate(.degrees180)) }
        Button("Straighten…") { perform(.straighten) }
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
            // A disabled tool's key does nothing, as its rail button does.
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
