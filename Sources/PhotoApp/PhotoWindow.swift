// PhotoWindow.swift: the root of a Photo window. It holds the one
// PhotoWorkspace (`model`) and the window's presentation state (zoom, the
// panel tab, the open file's URL, sheets and alerts, the Straighten draft the
// canvas previews), turns every PhotoIntent into a workspace method or a
// panel, and keeps the picture rendered (CanvasRenderer) whenever the
// workspace's revision moves. Canvas drags carry
// the pen's pressure (PointerPressure) and, while they last, AppKit's mouse
// event coalescing is off so every pointer sample arrives. Files go through
// ImageIOCodec; the open and save panels are AppKit's. Save writes over the
// open file in its own format; a new image or a HEIC goes to Save As, which
// asks where (PNG or JPEG by the name's extension) and makes that file the
// document. Export never changes which file the window holds. Three launch
// arguments let the UI journeys skip the panels: `-PhotoOpenFile <path>` opens
// a file at launch, `-PhotoExportTo <folder>` makes Export write there
// directly, and `-PhotoSaveTo <folder>` makes Save As write
// `<folder>/<name>.png`.
import AppKit
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

struct PhotoWindow: View {
    @State private var model = PhotoWorkspace()
    @State private var renderer = CanvasRenderer()
    @State private var zoom = 1.0
    @State private var viewport = CGSize.zero
    /// A new image waits to be fitted until the canvas has a size.
    @State private var fitPending = false
    @State private var tab = PhotoPanelTab.adjust
    @State private var documentURL: URL?
    @State private var note: String?
    @State private var problem: String?
    @State private var isExporting = false
    @State private var exportFormat = ImageFormat.png
    @State private var exportQuality = 0.9
    @State private var isResizing = false
    /// The Straighten sheet's choices; nil while it is closed.
    @State private var straightenDraft: StraightenDraft?
    @State private var isRenaming = false
    @State private var renameText = ""

    /// A sheet or the rename alert is up, so its text field gets Command-A.
    private var sheetPresented: Bool { isExporting || isResizing || straightenDraft != nil || isRenaming }

    /// The launch file opens in the first window only.
    @MainActor private static var launchFileOpened = false

    var body: some View {
        PhotoEditor(
            model: model, image: renderer.image, renderMilliseconds: renderer.milliseconds,
            note: renderer.failure ?? note, zoom: zoom, tab: tab,
            onTab: { tab = $0 }, onViewport: viewportChanged, onZoom: setZoom, perform: perform, straighten: straightenDraft)
            .navigationTitle(model.documentName ?? (model.canvas == nil ? "Photo" : "Untitled"))
            .focusedSceneValue(\.photoMenu, PhotoMenu(model: model, sheetPresented: sheetPresented, perform: perform))
            .onChange(of: model.revision) { renderer.show(model) }
            .onChange(of: model.canvas) {
                fitPending = true
                fit()
            }
            .sheet(isPresented: $isExporting) {
                ExportSheet(
                    format: exportFormat, quality: exportQuality, onFormat: { exportFormat = $0 },
                    onQuality: { exportQuality = $0 }, onExport: exportChosen, onCancel: { isExporting = false })
            }
            .sheet(isPresented: $isResizing) {
                if let canvas = model.canvas {
                    ImageSizeSheet(size: canvas, onResize: resize, onCancel: { isResizing = false })
                }
            }
            .sheet(isPresented: Binding(get: { straightenDraft != nil }, set: { if !$0 { straightenDraft = nil } })) {
                if let draft = straightenDraft {
                    StraightenSheet(
                        draft: draft, frame: model.straightenFrame(degrees: draft.degrees, cropToFit: draft.cropToFit),
                        onDraft: { straightenDraft = $0 },
                        onApply: { perform(.applyStraighten(degrees: draft.degrees, cropToFit: draft.cropToFit)) },
                        onCancel: { straightenDraft = nil })
                }
            }
            .alert("Rename Layer", isPresented: $isRenaming) {
                TextField("Name", text: $renameText).accessibilityIdentifier("photo.layer.name")
                Button("Rename", action: commitRename)
                Button("Cancel", role: .cancel) {}
            }
            .alert(problem ?? "", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .task {
                PointerPressure.watch()
                openLaunchFile()
            }
    }

    private func perform(_ intent: PhotoIntent) {
        switch intent {
        case .newImage:
            // 1920 x 1080 is a size CoreRaster always accepts, so this never throws.
            try? model.newCanvas(width: 1920, height: 1080)
            documentURL = nil
        case .open: chooseFile()
        case .openFile(let url): open(url)
        case .save: save()
        case .saveAs: saveAs()
        case .export: isExporting = model.canvas != nil
        case .imageSize: isResizing = model.canvas != nil
        case .rotate(let turn): model.rotateImage(turn)
        case .straighten: straightenDraft = model.canvas == nil ? nil : StraightenDraft()
        case .applyStraighten(let degrees, let cropToFit): straighten(degrees: degrees, cropToFit: cropToFit)
        case .undo: model.undo()
        case .redo: model.redo()
        case .tool(let tool): model.selectTool(tool)
        case .drag(let from, let to):
            // Every pointer sample while drawing, not AppKit's merged ones; the drag's end turns merging back on.
            NSEvent.isMouseCoalescingEnabled = false
            model.drag(
                from: Mask.Point(x: from.x, y: from.y), to: Mask.Point(x: to.x, y: to.y),
                pressure: PointerPressure.current, sampling: NSEvent.modifierFlags.contains(.option))
        case .endDrag:
            NSEvent.isMouseCoalescingEnabled = true
            model.endDrag()
        case .toolOption(let edit): model.setToolOption(edit)
        case .adjust(let edit): model.adjust(edit)
        case .endAdjust: model.endAdjust()
        case .selectAll: model.selectAll()
        case .deselect: model.deselect()
        case .deleteSelection: model.deleteSelection()
        case .fillSelection: model.fillSelection()
        case .applyCrop: model.applyCrop()
        case .cancelCrop: model.cancelCrop()
        case .selectLayer(let id): model.selectLayer(id)
        case .toggleVisibility(let id): model.toggleVisibility(id)
        case .opacity(let id, let percent): model.setOpacity(id, percent: percent)
        case .blendMode(let id, let mode): model.setBlendMode(id, mode)
        case .moveLayers(let from, let to): model.moveLayers(fromOffsets: Array(from), toOffset: to)
        case .addLayer: model.addLayer()
        case .deleteLayer: if let id = model.selectedLayerID { model.removeLayer(id) }
        case .renameLayer: beginRename()
        case .bringForward: model.bringSelectedLayerForward()
        case .sendBackward: model.sendSelectedLayerBackward()
        case .selectLayerAbove: model.selectLayerAbove()
        case .selectLayerBelow: model.selectLayerBelow()
        case .zoomIn: setZoom(ViewerZoom.zoomedIn(from: zoom))
        case .zoomOut: setZoom(ViewerZoom.zoomedOut(from: zoom))
        case .actualSize: setZoom(1)
        case .fit: fit()
        }
    }

    // MARK: Zoom

    private func setZoom(_ scale: Double) {
        zoom = min(max(scale.isFinite ? scale : 1, ViewerZoom.stops[0]), ViewerZoom.stops[ViewerZoom.stops.count - 1])
    }

    /// Fits the image in the canvas, once the canvas has been laid out.
    private func fit() {
        guard let canvas = model.canvas, viewport.width > 0, viewport.height > 0 else { return }
        fitPending = false
        let fitted = ViewerZoom.fitScale(
            artboard: CGSize(width: canvas.width, height: canvas.height), in: viewport, inset: SuiteSpacing.xxl)
        setZoom(fitted > 0 ? fitted : 1)
    }

    private func viewportChanged(_ size: CGSize) {
        viewport = size
        if fitPending { fit() }
    }

    // MARK: Files

    private func openLaunchFile() {
        guard !Self.launchFileOpened, let path = UserDefaults.standard.string(forKey: "PhotoOpenFile") else { return }
        Self.launchFileOpened = true
        open(URL(fileURLWithPath: path))
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    private func open(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let side = ImageIOCodec.pixelSize(of: data).flatMap {
                PhotoWorkspace.decodeLongestSide(width: $0.width, height: $0.height)
            }
            try model.open(data, name: url.lastPathComponent, codec: ImageIOCodec(), longestSide: side)
            documentURL = url
            note = side.map { "Opened at \($0) px on the longest side" }
        } catch {
            problem = "\(url.lastPathComponent) can't be opened. \(Self.reason(error))"
        }
    }

    /// Writes over the open file in its own format; a new image, or a file in
    /// a format Photo doesn't write, is Save As.
    private func save() {
        guard model.canvas != nil else { return }
        guard let url = documentURL, let format = ImageFormat(fileName: url.lastPathComponent) else { return saveAs() }
        write(to: url, as: format, quality: exportQuality, saving: true)
    }

    /// Asks where to save, PNG or JPEG by the name's extension; `-PhotoSaveTo` writes a PNG there without asking.
    private func saveAs() {
        guard model.canvas != nil else { return }
        if let folder = UserDefaults.standard.string(forKey: "PhotoSaveTo") {
            let url = URL(fileURLWithPath: folder).appending(path: model.fileName(for: .png))
            return write(to: url, as: .png, quality: exportQuality, saving: true)
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = model.fileName(for: ImageFormat(fileName: model.documentName ?? "") ?? .png)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url, as: ImageFormat(fileName: url.lastPathComponent) ?? .png, quality: exportQuality, saving: true)
    }

    private func exportChosen() {
        isExporting = false
        let name = model.fileName(for: exportFormat)
        if let folder = UserDefaults.standard.string(forKey: "PhotoExportTo") {
            write(to: URL(fileURLWithPath: folder).appending(path: name), as: exportFormat, quality: exportQuality, saving: false)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [exportFormat == .png ? .png : .jpeg]
        panel.nameFieldStringValue = name
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url, as: exportFormat, quality: exportQuality, saving: false)
    }

    /// Saving (Save, Save As) makes `url` the window's file; exporting doesn't.
    private func write(to url: URL, as format: ImageFormat, quality: Double, saving: Bool) {
        let (workspace, opened) = (model, documentURL)
        note = saving ? "Saving…" : "Exporting…"
        Task {
            do {
                let data = try await workspace.export(as: format, quality: quality, codec: ImageIOCodec())
                try data.write(to: url, options: .atomic)
                // A file opened meanwhile keeps its own name and URL.
                if saving, documentURL == opened {
                    documentURL = url
                    model.didSave(as: url.lastPathComponent)
                }
                note = "\(saving ? "Saved" : "Exported") \(url.lastPathComponent)"
            } catch {
                note = nil
                problem = "\(url.lastPathComponent) couldn't be written. \(Self.reason(error))"
            }
        }
    }

    private func resize(width: Int, height: Int) {
        isResizing = false
        do {
            try model.resizeImage(width: width, height: height)
        } catch {
            problem = "The image can't be resized to \(width) × \(height). \(Self.reason(error))"
        }
    }

    /// Turns the layers off the main actor (seconds on a big photo), then
    /// commits them unless the image changed meanwhile.
    private func straighten(degrees: Double, cropToFit: Bool) {
        straightenDraft = nil
        let workspace = model
        note = "Straightening…"
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try workspace.straightened(degrees: degrees, cropToFit: cropToFit)
                }.value
                note = nil
                if let result, !model.commitStraighten(result) {
                    note = "The image changed while straightening, so it wasn't turned."
                }
            } catch {
                note = nil
                problem = "The image can't be straightened by \(degrees)°. \(Self.reason(error))"
            }
        }
    }

    private static func reason(_ error: Error) -> String {
        switch error {
        case let failure as ImageIOCodec.Failure: failure.description
        case RasterError.invalid(let message): "The image is not valid: \(message)."
        default: error.localizedDescription
        }
    }

    // MARK: Layers

    private func beginRename() {
        guard let layer = model.selectedLayer else { return }
        renameText = layer.name
        isRenaming = true
    }

    private func commitRename() {
        guard let id = model.selectedLayerID else { return }
        model.renameLayer(id, to: renameText)
    }
}
