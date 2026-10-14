// PhotoEditor.swift: what a Photo window shows, laid out on SuiteUI's
// EditorShell: the top bar (the document menu with New Image, Open…, Save,
// Save As… and Export…; file commands, the Image menu, undo and redo, zoom),
// the tool rail, the canvas with its rulers (and the Clone source's mark), the Adjust | Layers panel
// and the status line (zoom, image size, the active tool, render time). Values in, intents
// out: it reads the workspace and sends every action to `perform`, so the
// same view draws the live window and the snapshots. A control that can't act
// now is disabled with a tooltip saying why. Every top bar command carries a
// `photo.bar.*` accessibility identifier for the UI journeys and the app
// audit; Undo and Redo keep theirs whatever edit they name. The canvas shows
// no scrollers: AppKit's scroller parts are unnamed buttons (the app audit's
// unnamed check), and a zoomed image still pans by scrolling.
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
    /// The Straighten sheet's choices while it is open, previewed on the canvas.
    var straighten: StraightenDraft?

    var body: some View {
        EditorShell {
            PhotoTopBar(model: model, perform: perform)
        } rail: {
            ToolbarGroup(tools: PhotoTool.allCases, selected: model.tool, style: .rail) { perform(.tool($0)) }
        } canvas: {
            PhotoCanvas(
                model: model, image: image, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform,
                straighten: straighten)
                .scrollIndicators(.never)
        } panel: {
            PhotoPanel(model: model, tab: tab, onTab: onTab, perform: perform)
        } status: {
            ViewerStatusBar(zoom: model.canvas == nil ? 0 : zoom, size: model.viewerSizeText) {
                if let note { Text(note) }
                if model.canvas != nil { Text(model.tool.title) }
                if let renderMilliseconds { Text("\(Int(renderMilliseconds.rounded())) ms render") }
            }
        }
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
            Button("Save As…") { perform(.saveAs) }.disabled(noImage != nil).accessibilityIdentifier("photo.bar.save-as")
            Button("Export…") { perform(.export) }.disabled(noImage != nil)
        } content: {
            EditorBarItem(ToolbarAction("Open", systemImage: "folder") { perform(.open) })
                .accessibilityIdentifier("photo.bar.open")
            EditorBarItem(ToolbarAction("Save", systemImage: "square.and.arrow.down", unavailableHelp: noImage) {
                perform(.save)
            })
            .accessibilityIdentifier("photo.bar.save")
            EditorBarItem(ToolbarAction("Export", systemImage: "square.and.arrow.up", unavailableHelp: noImage) {
                perform(.export)
            })
            .accessibilityIdentifier("photo.bar.export")
            EditorBarMenu("Image", systemImage: "photo", unavailableHelp: noImage) {
                PhotoImageMenu(perform: perform)
            }
            .accessibilityIdentifier("photo.bar.image")
            EditorBarDivider()
            EditorBarItem(
                ToolbarAction(
                    model.undoActionName, systemImage: "arrow.uturn.backward",
                    unavailableHelp: model.canUndo ? nil : "Nothing to undo.") { perform(.undo) },
                showsTitle: false)
            .accessibilityIdentifier("photo.bar.undo")
            EditorBarItem(
                ToolbarAction(
                    model.redoActionName, systemImage: "arrow.uturn.forward",
                    unavailableHelp: model.canRedo ? nil : "Nothing to redo.") { perform(.redo) },
                showsTitle: false)
            .accessibilityIdentifier("photo.bar.redo")
            Spacer(minLength: SuiteSpacing.s)
            EditorBarItem(
                ToolbarAction("Zoom Out", systemImage: "minus.magnifyingglass", unavailableHelp: noImage) {
                    perform(.zoomOut)
                }, showsTitle: false)
            .accessibilityIdentifier("photo.bar.zoom-out")
            EditorBarItem(
                ToolbarAction("Fit on Screen", systemImage: "arrow.up.left.and.arrow.down.right", unavailableHelp: noImage) {
                    perform(.fit)
                }, showsTitle: false)
            .accessibilityIdentifier("photo.bar.fit")
            EditorBarItem(
                ToolbarAction("Zoom In", systemImage: "plus.magnifyingglass", unavailableHelp: noImage) {
                    perform(.zoomIn)
                }, showsTitle: false)
            .accessibilityIdentifier("photo.bar.zoom-in")
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

/// The canvas: the rendered picture on the checkerboard with the selection and
/// a pending crop over it, and with Clone its sampled source, or the empty
/// state. Drags go to the active tool (Option-click with Clone samples the
/// source, in PhotoWindow); with the canvas focused, V M B E S C pick tools, Delete clears the selection
/// (Shift-Delete fills it), Return applies a crop and Escape cancels it or
/// deselects. Dropping an image file opens it. While the Straighten sheet is
/// open the picture turns by its angle under StraightenMarks.
struct PhotoCanvas: View {
    let model: PhotoWorkspace
    let image: CGImage?
    let zoom: Double
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }
    var straighten: StraightenDraft?

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
                            .rotationEffect(.degrees(straighten?.degrees ?? 0))
                    }
                } overlay: {
                    if let selection = model.selection { SelectionOutline(rect: selection.cgRect, zoom: zoom) }
                    if let crop = model.pendingCrop { CropShade(rect: crop.cgRect, documentSize: size, zoom: zoom) }
                    if model.tool == .clone, let source = model.cloneSource {
                        CloneSourceMark(point: CGPoint(x: source.point.x, y: source.point.y), zoom: zoom)
                    }
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

/// Where the Clone tool copies from: a white ring over a black one with a
/// cross, so it reads on any pixels. A plain placeholder until SuiteUI has a
/// canvas point mark (#706).
struct CloneSourceMark: View {
    let point: CGPoint
    let zoom: Double

    var body: some View {
        let center = CGPoint(x: point.x * zoom, y: point.y * zoom), radius = SuiteSpacing.s
        let mark = Path { path in
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.move(to: CGPoint(x: center.x - radius - SuiteSpacing.xs, y: center.y))
            path.addLine(to: CGPoint(x: center.x + radius + SuiteSpacing.xs, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - radius - SuiteSpacing.xs))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius + SuiteSpacing.xs))
        }
        ZStack {
            mark.stroke(SuiteColor.overlayInk, lineWidth: 3)
            mark.stroke(SuiteColor.overlayPaper, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension PixelRect {
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
