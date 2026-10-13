// PhotoEditor.swift: what a Photo window shows, laid out on SuiteUI's
// EditorShell: the top bar (file commands, the Image menu, undo and redo,
// zoom), the tool rail, the canvas with its rulers, the Adjust | Layers panel
// and the status line (zoom, image size, render time). Values in, intents
// out: it reads the workspace and sends every action to `perform`, so the
// same view draws the live window and the snapshots. A control that can't act
// now is disabled with a tooltip saying why.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoEditor: View {
    let model: PhotoWorkspace
    var image: CGImage?
    var renderMilliseconds: Double?
    var note: String?
    var zoom = 1.0
    var tab = PhotoPanelTab.adjust
    var onTab: @MainActor (PhotoPanelTab) -> Void = { _ in }
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }

    var body: some View {
        EditorShell {
            PhotoTopBar(model: model, perform: perform)
        } rail: {
            ToolbarGroup(tools: PhotoTool.allCases, selected: model.tool, style: .rail) { perform(.tool($0)) }
        } canvas: {
            PhotoCanvas(model: model, image: image, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform)
        } panel: {
            PhotoPanel(model: model, tab: tab, onTab: onTab, perform: perform)
        } status: {
            ViewerStatusBar(zoom: model.canvas == nil ? 0 : zoom, size: sizeText) {
                if let note { Text(note) }
                if let renderMilliseconds { Text("\(Int(renderMilliseconds.rounded())) ms render") }
            }
        }
    }

    private var sizeText: String {
        guard let canvas = model.canvas else { return "No image" }
        let selection = model.selection.map { "  ·  Selection \($0.width) × \($0.height)" } ?? ""
        return "\(canvas.width) × \(canvas.height) px\(selection)"
    }
}

/// The top bar: the document menu, Open, Save, Export, the Image menu, Undo
/// and Redo, then zoom.
struct PhotoTopBar: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        let noImage = model.canvas == nil ? "Open or create an image first." : nil
        EditorTopBar(app: "Photo", document: model.canvas == nil ? nil : model.documentName ?? "Untitled") {
            Button("New Image") { perform(.newImage) }
            Button("Open…") { perform(.open) }
            Divider()
            Button("Save") { perform(.save) }.disabled(noImage != nil)
            Button("Export…") { perform(.export) }.disabled(noImage != nil)
        } content: {
            EditorBarItem(ToolbarAction("Open", systemImage: "folder") { perform(.open) })
            EditorBarItem(ToolbarAction("Save", systemImage: "square.and.arrow.down", unavailableHelp: noImage) {
                perform(.save)
            })
            EditorBarItem(ToolbarAction("Export", systemImage: "square.and.arrow.up", unavailableHelp: noImage) {
                perform(.export)
            })
            EditorBarMenu("Image", systemImage: "photo", unavailableHelp: noImage) {
                PhotoImageMenu(perform: perform)
            }
            EditorBarDivider()
            EditorBarItem(
                ToolbarAction(
                    model.undoActionName, systemImage: "arrow.uturn.backward",
                    unavailableHelp: model.canUndo ? nil : "Nothing to undo.") { perform(.undo) },
                showsTitle: false)
            EditorBarItem(
                ToolbarAction(
                    model.redoActionName, systemImage: "arrow.uturn.forward",
                    unavailableHelp: model.canRedo ? nil : "Nothing to redo.") { perform(.redo) },
                showsTitle: false)
            Spacer(minLength: SuiteSpacing.s)
            EditorBarItem(
                ToolbarAction("Zoom Out", systemImage: "minus.magnifyingglass", unavailableHelp: noImage) {
                    perform(.zoomOut)
                }, showsTitle: false)
            EditorBarItem(
                ToolbarAction("Fit on Screen", systemImage: "arrow.up.left.and.arrow.down.right", unavailableHelp: noImage) {
                    perform(.fit)
                }, showsTitle: false)
            EditorBarItem(
                ToolbarAction("Zoom In", systemImage: "plus.magnifyingglass", unavailableHelp: noImage) {
                    perform(.zoomIn)
                }, showsTitle: false)
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
    }
}

/// The canvas: the rendered picture on the checkerboard with the selection and
/// a pending crop over it, or the empty state. Drags go to the active tool;
/// with the canvas focused, V M B E C pick tools, Delete clears the selection
/// (Shift-Delete fills it), Return applies a crop and Escape cancels it or
/// deselects. Dropping an image file opens it.
struct PhotoCanvas: View {
    let model: PhotoWorkspace
    let image: CGImage?
    let zoom: Double
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }

    var body: some View {
        Group {
            if let canvas = model.canvas {
                let size = CGSize(width: canvas.width, height: canvas.height)
                CanvasViewport(
                    documentSize: size, zoom: zoom, pointer: model.tool.pointer, onSize: onViewport, onZoom: onZoom,
                    onDrag: { perform(.drag($0, $1)) }, onDragEnd: { perform(.endDrag) }, onKey: key
                ) {
                    if let image {
                        Image(decorative: image, scale: 1).resizable().interpolation(zoom >= 2 ? .none : .high)
                    }
                } overlay: {
                    if let selection = model.selection { SelectionOutline(rect: selection.cgRect, zoom: zoom) }
                    if let crop = model.pendingCrop { CropShade(rect: crop.cgRect, documentSize: size, zoom: zoom) }
                }
            } else {
                EmptyStateView(
                    "No Image Open", systemImage: "photo.on.rectangle",
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
            perform(.applyCrop)
        case .escape:
            perform(model.pendingCrop != nil ? .cancelCrop : .deselect)
        default:
            guard let tool = PhotoTool.allCases.first(where: { $0.shortcut.map(String.init) == press.characters.lowercased() })
            else { return .ignored }
            perform(.tool(tool))
        }
        return .handled
    }
}

extension PixelRect {
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
