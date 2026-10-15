// PhotoWindow.swift: the root of a Photo window. It holds the one
// PhotoWorkspace (`model`) and the window's presentation state (zoom, the
// panel tab, the open file's URL, sheets and alerts, the Straighten draft the
// canvas previews, and the v2 presentation flags), turns every PhotoIntent
// into a workspace method or a panel, and keeps the picture rendered (CanvasRenderer) whenever the
// workspace's revision moves, and clears the status line's message 4 s after
// it appears. Canvas drags carry
// the pen's pressure (PointerPressure) and, while they last, AppKit's mouse
// event coalescing is off so every pointer sample arrives; StrokePacer hands
// them to the workspace once per display frame. Its workspace runs on
// `fileServices(.live)`. Open, Save, Save As and their launch arguments live in
// PhotoWindow+File.swift, Export's write in PhotoWindow+Export.swift.
//
// Each v2 area's intents go to its PhotoWindow+<Area>.swift (file, edit,
// crop, history, select, adjustment layer, transform, export, sample), and
// each area's identity modifier (Photo<Area>Area) is applied here, so a
// feature keeps its own state, alerts, dialogs and timers in its area file.
// The window's state is internal so those files can reach it. Return
// (`confirm`) and Escape (`dismiss`) ask the transform area first, then fall
// back to the crop and the selection.
import AppKit
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoWindow: View {
    @State var model = PhotoWorkspace(services: PhotoWindow.fileServices(.live))
    @State var renderer = CanvasRenderer()
    @State var pacer = StrokePacer()
    @State var zoom = 1.0
    @State var viewport = CGSize.zero
    /// A new image waits to be fitted until the canvas has a size.
    @State var fitPending = false
    @State var tab = PhotoPanelTab.adjust
    @State var documentURL: URL?
    @State var note: String?
    @State var problem: String?
    @State var isExporting = false
    @State var exportFormat = ImageFormat.png
    @State var exportQuality = 0.9
    @State var isResizing = false
    /// The Straighten sheet's choices; nil while it is closed.
    @State var straightenDraft: StraightenDraft?
    @State var isRenaming = false
    @State var renameText = ""
    // v2 presentation flags (PV-0); each belongs to the area file named.
    /// A recovered document waiting for Restore or Discard (PhotoWindow+File.swift, PV-1).
    @State var recoveryOffer: RecoveryEntry?
    /// Why Paste refused, for its alert (PhotoWindow+Edit.swift, PV-2).
    @State var pasteRefusal: String?
    /// Free Transform's box and its Apply and Cancel are up (PhotoWindow+Transform.swift, PV-7).
    @State var isTransforming = false
    /// The Export sheet's choices while it is open (PhotoWindow+Export.swift, PV-8).
    @State var exportDraft: ExportOptions?

    /// A sheet or the rename alert is up, so Select > All never selects the canvas.
    var isPresenting: Bool { isExporting || isResizing || straightenDraft != nil || isRenaming }

    /// The launch file opens in the first window only.
    @MainActor static var launchFileOpened = false

    var body: some View {
        PhotoEditor(
            model: model, tiles: renderer.tiles, renderMilliseconds: renderer.milliseconds,
            note: renderer.failure ?? note, zoom: zoom, tab: tab,
            onTab: { tab = $0 }, onViewport: viewportChanged, onZoom: setZoom, perform: perform, straighten: straightenDraft)
            .navigationTitle(model.documentName ?? (model.canvas == nil ? "Photo" : "Untitled"))
            .focusedSceneValue(\.photoMenu, PhotoMenu(model: model, isPresenting: isPresenting, perform: perform))
            .onChange(of: model.revision) { renderer.show(model) }
            .onChange(of: model.canvas) {
                fitPending = true
                fit()
            }
            // The status line's message goes 4 s after it appears; a new message restarts the wait.
            .task(id: model.statusMessage) {
                guard model.statusMessage != nil else { return }
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                model.clearStatus()
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
            .modifier(PhotoFileArea(model: model, perform: perform))
            .modifier(PhotoEditArea(model: model, perform: perform))
            .modifier(PhotoCropArea(model: model, perform: perform))
            .modifier(PhotoHistoryArea(model: model, perform: perform))
            .modifier(PhotoSelectArea(model: model, perform: perform))
            .modifier(PhotoAdjustmentLayerArea(model: model, perform: perform))
            .modifier(PhotoTransformArea(model: model, perform: perform))
            .modifier(PhotoExportArea(model: model, perform: perform))
            .modifier(PhotoSampleArea(model: model, perform: perform))
    }

    func perform(_ intent: PhotoIntent) {
        // Drag samples still waiting for the display frame land first.
        if case .drag = intent {} else { pacer.flush() }
        switch intent {
        case .newImage:
            // 1920 x 1080 is a size CoreRaster always accepts, so this never throws.
            try? model.newCanvas(width: 1920, height: 1080)
            documentURL = nil
        case .open: chooseFile()
        case .openFile(let url): open(url)
        case .save: save()
        case .saveAs: saveAs()
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
            let move = (
                Mask.Point(x: from.x, y: from.y), Mask.Point(x: to.x, y: to.y), PointerPressure.current,
                NSEvent.modifierFlags.contains(.option))
            pacer.add(move) { model.drags($0) }
        case .endDrag:
            NSEvent.isMouseCoalescingEnabled = true
            pacer.stop()
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
        case .file(let intent): performFile(intent)
        case .edit(let intent): performEdit(intent)
        case .crop(let intent): performCrop(intent)
        case .history(let intent): performHistory(intent)
        case .select(let intent): performSelect(intent)
        case .adjustmentLayer(let intent): performAdjustmentLayer(intent)
        case .transform(let intent): performTransform(intent)
        case .export(let intent): performExport(intent)
        case .sample(let intent): performSample(intent)
        case .confirm: if confirmTransform() {} else { model.applyCrop() }
        case .dismiss:
            if dismissTransform() {} else if model.pendingCrop != nil { model.cancelCrop() } else { model.deselect() }
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

    // MARK: Image

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
