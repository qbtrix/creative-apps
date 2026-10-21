// PhotoWindow.swift: the root of a Photo window. It holds the one
// PhotoWorkspace (`model`) and the window's presentation state (zoom, the
// open file's URL, sheets and alerts, the Straighten draft the
// canvas previews, and the v2 presentation flags), turns every PhotoIntent
// into a workspace method or a panel, and keeps the picture rendered (CanvasRenderer) whenever the
// workspace's revision moves (on the app's View > Rendering backend), and clears the status line's message 4 s after
// it appears. Canvas drags carry the pen's pressure (SuiteUI's SuitePointerPressure), the
// keys held (DragModifiers) and the zoom, and, while they last, AppKit's mouse
// event coalescing is off so every pointer sample arrives; StrokePacer (SuiteUI's pacer) hands
// them to the workspace as they come, at most twice a display frame, and each
// apply starts the picture's render at once. A brush, eraser, clone or heal
// stroke draws on LiveStroke's LiveCopy and comes back once, at its end or before
// any other intent, so drawing never re-runs the panels. Its workspace runs on
// `fileServices(.live)`, or under `-PhotoFixture` on the fixture's fakes
// (`launchOptions`, read once from the process; S-12), whose picture it
// renders and keeps fitted while the window settles, until the user zooms. Open, Save, Save As and their
// launch arguments live in PhotoWindow+File.swift, Export's write in
// PhotoWindow+Export.swift.
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
    @State var model: PhotoWorkspace
    @State var renderer = CanvasRenderer()
    @State var pacer = StrokePacer()
    @State var liveStroke = LiveStroke()
    @State var dragLine = LiveDragLine()
    @State var zoom = 1.0
    @State var viewport = CGSize.zero
    /// A new image waits to be fitted until the canvas has a size.
    @State var fitPending = false
    /// A launch fixture's picture refits as the window settles, until the user zooms.
    @State var fitFollowsViewport = false
    /// The zoom the last fit chose; a zoom that differs means the user zoomed.
    @State var fittedZoom: Double?
    @State var documentURL: URL?
    @State var note: String?
    /// The error or refusal the window's alert shows; nil while it is closed.
    @State var problem: PhotoProblem?
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
    /// The file state Save and Open share with PhotoFileArea (PhotoWindow+File.swift, PV-1).
    @State var files = PhotoFileSession()
    /// Why Paste refused, for its alert (PhotoWindow+Edit.swift, PV-2).
    @State var pasteRefusal: String?
    /// Free Transform's box and its Apply and Cancel are up (PhotoWindow+Transform.swift, PV-7).
    @State var isTransforming = false
    /// The Export sheet's choices while it is open (PhotoWindow+Export.swift, PV-8).
    @State var exportDraft: ExportOptions?
    /// The inspector's tab (PhotoWindow+History.swift, history-panel PH-2).
    @State var inspectorTab = PhotoInspectorTab.adjust
    /// The app's View > Rendering; nil in tests, which draw on the CPU.
    @Environment(\.photoRendering) private var rendering

    /// A sheet or the rename alert is up, so Select > All never selects the canvas.
    var isPresenting: Bool { model.isExportSheetOpen || isResizing || straightenDraft != nil || isRenaming }

    /// The launch file opens in the first window only.
    @MainActor static var launchFileOpened = false

    /// This process's `-PhotoFixture`, read once.
    nonisolated static let launchOptions = PhotoLaunchOptions(arguments: ProcessInfo.processInfo.arguments)

    /// The fixture on the fakes under `-PhotoFixture`, else a workspace on `fileServices(.live)`.
    nonisolated static func launchWorkspace() -> PhotoWorkspace {
        PhotoWorkspace.launch(launchOptions) ?? PhotoWorkspace(services: fileServices(.live))
    }

    /// A window on `model`: the launch workspace in the app, a test's own in tests, at `zoom`.
    init(model: PhotoWorkspace = PhotoWindow.launchWorkspace(), zoom: Double = 1) {
        _model = State(initialValue: model)
        _zoom = State(initialValue: zoom)
    }

    var body: some View {
        PhotoEditor(
            model: model, tiles: renderer.tiles, renderMilliseconds: renderer.milliseconds,
            renderBackend: renderer.backend, note: renderer.failure ?? note, zoom: zoom, onViewport: viewportChanged, onZoom: setZoom, perform: perform,
            straighten: straightenDraft)
            .environment(\.photoDragLine, dragLine)
            .focusedSceneValue(\.photoMenu, PhotoMenu(model: model, isPresenting: isPresenting, perform: perform))
            .onChange(of: model.revision) { renderer.show(model) }
            .onAppear { if let rendering { renderer.follow(rendering) { renderer.show(model) } } }
            .onChange(of: model.canvas) {
                fitFollowsViewport = false
                fitPending = true
                fit()
            }
            // The status line's message goes 4 s after it appears; a new message restarts the wait.
            .task(id: model.statusMessage) {
                guard model.statusMessage != nil else { return }
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                takeStroke()
                model.clearStatus()
            }
            .sheet(isPresented: Binding(get: { model.isExportSheetOpen }, set: { if !$0 { model.dismissExport() } })) {
                ExportSheet(
                    format: exportFormat, quality: exportQuality, onFormat: { exportFormat = $0 },
                    onQuality: { exportQuality = $0 }, onExport: exportChosen, onCancel: { model.dismissExport() })
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
            } message: {
                Text("Enter a new name for the layer.")
            }
            .alert(
                problem?.title ?? "",
                isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } }),
                presenting: problem
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { shown in
                Text(shown.message)
            }
            .task {
                SuitePointerPressure.watch()
                showLaunchImage()
                openLaunchFile()
            }
            .modifier(PhotoFileArea(model: model, files: files, perform: perform))
            .modifier(PhotoEditArea(model: model, perform: perform))
            .modifier(PhotoCropArea(model: model, perform: perform))
            .modifier(PhotoHistoryArea(model: model, perform: perform, tab: inspectorTab))
            .modifier(PhotoSelectArea(model: model, perform: perform))
            .modifier(PhotoAdjustmentLayerArea(model: model, perform: perform))
            .modifier(PhotoTransformArea(model: model, perform: perform))
            .modifier(PhotoExportArea(model: model, perform: perform))
            .modifier(PhotoSampleArea(model: model, perform: perform))
    }

    func perform(_ intent: PhotoIntent) {
        // Drag samples still waiting for the display frame land first, then a live stroke goes back.
        if case .drag = intent {} else {
            pacer.flush()
            takeStroke()
        }
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
                Mask.Point(x: from.x, y: from.y), Mask.Point(x: to.x, y: to.y), SuitePointerPressure.current,
                DragModifiers(flags: NSEvent.modifierFlags))
            // The picture starts at once, not after SwiftUI's next pass reaches `.onChange`. A paint
            // stroke draws on LiveStroke's copy, so its samples don't re-run the panels.
            pacer.add(move) { moves in
                if samplePress(moves) { return }
                // A Gradient drag's later samples move only its line, on LiveDragLine's copy.
                if dragLine.drags(moves, on: model, zoom: zoom) { return }
                guard let painted = liveStroke.drags(moves, on: model, zoom: zoom) else {
                    model.drags(moves, zoom: zoom)
                    return renderer.show(model)
                }
                renderer.show(painted, quietly: true)
                // A refusal ("Select an image layer…") shows at the press, not at the release.
                if painted.statusMessage != model.statusMessage { takeStroke() }
            }
        case .endDrag:
            NSEvent.isMouseCoalescingEnabled = true
            pacer.stop()
            model.endDrag()
        case .toolOption(let edit): model.setToolOption(edit)
        case .gradientOption(let intent): model.runGradientOption(intent)
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
        case .zoomIn: setZoom(ZoomMath.zoomedIn(from: zoom))
        case .zoomOut: setZoom(ZoomMath.zoomedOut(from: zoom))
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
        case .place(let intent): performPlace(intent)
        case .text(let intent): performType(intent)
        case .confirm: if confirmTransform() {} else { model.applyCrop() }
        case .dismiss:
            if dismissTransform() {} else if model.pendingCrop != nil { model.cancelCrop() } else { model.deselect() }
        }
    }

    /// A live paint stroke's or drag line's copy back into the workspace: one SwiftUI pass for the stroke.
    private func takeStroke() {
        if let painted = liveStroke.take() { model.adoptLiveStroke(painted) }
        if let lined = dragLine.take() { model.adoptLiveStroke(lined) }
    }

    // MARK: Zoom

    /// A fixture's picture is there before any change, so render and fit it,
    /// and keep it fitted while the window settles until the user zooms.
    private func showLaunchImage() {
        guard model.canvas != nil else { return }
        renderer.show(model)
        fitFollowsViewport = true
        fitPending = true
        fit()
    }

    /// Sets the zoom within ZoomMath's range (10% to 3200%).
    private func setZoom(_ scale: Double) {
        zoom = ZoomMath.clamped(scale.isFinite ? scale : 1)
    }

    /// Fits the image in the canvas clear of the floating palette (every tool shows while an image is
    /// open), once the canvas has been laid out.
    private func fit() {
        guard let canvas = model.canvas, viewport.width > 0, viewport.height > 0 else { return }
        fitPending = false
        let toolCount = PhotoTool.allCases.count
        // The fit EditorDetail hands Command-0, so a fitted image clears the floating palette.
        let paletteFit: @Sendable (CGSize, CGSize) -> Double = { viewport, artboard in
            EditorDetailLayout(viewport: viewport, toolCount: toolCount).fitScale(artboard: artboard)
        }
        setZoom(ZoomMath.fit(document: CGSize(width: canvas.width, height: canvas.height), in: viewport, using: paletteFit))
        fittedZoom = zoom
    }

    private func viewportChanged(_ size: CGSize) {
        viewport = size
        if fitPending || (fitFollowsViewport && zoom == fittedZoom) {
            fit()
        } else {
            fitFollowsViewport = false
        }
    }

    // MARK: Image

    private func resize(width: Int, height: Int) {
        isResizing = false
        do {
            try model.resizeImage(width: width, height: height)
        } catch {
            problem = PhotoProblem("The image can't be resized to \(width) × \(height).", Self.reason(error))
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
                problem = PhotoProblem("The image can't be straightened by \(degrees)°.", Self.reason(error))
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

/// The window alert's words: a short title and the sentence that says why.
/// Every alert carries both, since an alert with no message leaves an empty
/// text field in the sheet that the app audit reads as invisible text.
struct PhotoProblem {
    let title: String
    let message: String

    init(_ title: String, _ message: String) {
        self.title = title
        self.message = message
    }
}
