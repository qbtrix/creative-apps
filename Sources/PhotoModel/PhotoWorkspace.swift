// PhotoWorkspace.swift: the state behind Photo's window (raster editing): the
// open image's size and name, its layer stack (top first) with each layer's
// pixels, the picked layers (a kernel Selection whose primary is the selected
// layer), the active tool, the brush's and the eraser's
// options (each tool keeps its own), the image
// adjustments, the marquee selection and a pending crop, the clone source, and
// the undo history.
// Linux-safe: no UI imports. PhotoApp changes it only through the methods here
// and in the extensions beside it (PhotoStroke, PhotoSelection, PhotoHistory,
// PhotoImageFile, PhotoImageOps, PhotoStraighten, PhotoRetouch, PhotoMask).
// It also holds the v2 state (PV-0): the use cases (`services`), the selection
// mask, layer masks, the crop aspect, a free transform draft, the eyedropper's
// sample size, the export choices, the open file's kind and a status message.
//
// Invariants: with an image open there is at least one layer, the selection
// names one of them, and `pixels` holds exactly one buffer per *pixel* layer
// (an adjustment layer has none).
// `revision` goes up with every change to what the canvas shows, and
// `damage(since:)` says which part of the canvas changed since an older
// revision, so the renderer redraws only that. Every change to the document is
// one undo step (PhotoHistory). Every palette tool acts through
// `drag(from:to:)`; a tool that does nothing there stays disabled with
// `unavailableHelp` (PhotoToolsTests checks this).
import CoreRaster
import SuiteImaging
import SuiteKernel

/// The tools on Photo's floating tool palette.
public enum PhotoTool: String, CaseIterable, Sendable {
    case move, marquee, brush, eraser, clone
    /// Spot Heal (fill-heal): a click heals a spot from its surroundings. Before
    /// Heal, so J picks it first once it works.
    case spotHeal = "spot-heal"
    case heal
    /// Remove (fill-heal): paint over an object; its area fills from around it.
    case remove
    case crop, eyedropper
    /// Paint Bucket (fill-heal): a click fills the seed's colour region. Before
    /// Gradient, so G picks it first once it works.
    case bucket
    case gradient, text, pen

    /// The retouch tools' help until their commands reach Photo (fill-heal FH-7, FH-8).
    public static let retouchHelp = "Fill and heal arrive with fill-heal FH-8."

    /// Why the palette shows this tool disabled, as its tooltip; nil once the
    /// tool works. Every other tool works: the canvas sends its drags to
    /// `drag`. The eyedropper's text is the fallback; the workspace's
    /// `toolHelp` enables it, since it reads the kernel's mean.
    public var unavailableHelp: String? {
        switch self {
        case .eyedropper: "Not built yet (PV-9)."
        case .bucket, .spotHeal, .remove: Self.retouchHelp
        default: nil
        }
    }

    public var isEnabled: Bool { unavailableHelp == nil }
}

/// The open image's size in pixels.
public struct CanvasSize: Sendable, Hashable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    var rect: PixelRect { PixelRect(x: 0, y: 0, width: width, height: height) }
}

public struct PhotoWorkspace: Sendable {
    /// The open image's size; nil with no image open.
    public internal(set) var canvas: CanvasSize?
    /// The open file's name ("beach.jpg"); nil for a new image.
    public internal(set) var documentName: String?
    /// The layer stack, top first.
    public internal(set) var layers: [PhotoLayer] = []
    /// Each layer's pixels, by layer id, in tiles (TiledPixels).
    public internal(set) var pixels: [PhotoLayer.ID: TiledPixels] = [:]
    /// The picked layers, primary last, on the kernel's Selection (PhotoLayerSelection+Kernel.swift).
    var layerSelection = Selection<PhotoLayer.ID>()
    /// The layer the inspector, the brush and the Move tool act on: the
    /// selection's primary. Setting it makes that layer the whole selection;
    /// nil clears it.
    public internal(set) var selectedLayerID: PhotoLayer.ID? {
        get { layerSelection.primary }
        set {
            if let newValue { layerSelection.replace([newValue]) } else { layerSelection.clear() }
        }
    }
    public private(set) var tool: PhotoTool = .move
    /// The brush's options; its color is also the marquee's Fill color.
    public private(set) var brushOptions = ToolOptions()
    /// The eraser's own size, hardness and opacity; it has no color.
    public private(set) var eraserOptions = ToolOptions()
    /// The Paint Bucket's Tolerance, Contiguous and All Layers (fill-heal FH-3);
    /// changed by `setBucketOption` (PhotoBucketOptions.swift).
    public internal(set) var bucketOptions = BucketOptions()
    public internal(set) var adjustments = AdjustmentSettings()
    /// The marquee selection in canvas pixels; nil for none.
    public internal(set) var selection: PixelRect?
    /// The crop rectangle being drawn, before Apply Crop; nil for none.
    public internal(set) var pendingCrop: PixelRect?
    /// Where the clone stamp copies from (PhotoRetouch); nil until sampled.
    public internal(set) var cloneSource: CloneSource?
    /// Goes up with every change to what the canvas shows.
    public private(set) var revision = 0
    /// Goes up with every such change except an adjustment's (curvesHistogramKey).
    private(set) var contentRevision = 0
    var history = PhotoHistory()
    /// The drag in progress, between its first `drag` and `endDrag`.
    var stroke: PhotoStroke?
    /// Recent damage, oldest first, for `damage(since:)`.
    private var damageLog: [(revision: Int, damage: PhotoDamage)] = []
    /// The number in the next layer's id; ids are never reused.
    var nextLayerNumber = 1

    // v2 state (PV-0). Each belongs to the extension file named; besides it,
    // start() resets them all, PhotoHistory restores masks and the selection on
    // undo, and PhotoStroke paints into a mask through paintTarget().
    /// The use cases (PhotoServices); `.live` in the app, `.fake` under -PhotoFixture.
    public internal(set) var services: PhotoServices = .live
    /// The selection's coverage when it isn't an exact rectangle (PhotoSelectionMask.swift).
    public internal(set) var selectionMask: Mask?
    /// The selection's kernel recipe and Reselect's (PhotoArea+Kernel.swift).
    var area = PhotoArea()
    /// The Marquee tool's shape and feather (PhotoSelectionMask.swift).
    public internal(set) var selectionOptions = SelectionOptions()
    /// Each masked layer's mask, its own size, coverage as gray, alpha 1 (PhotoMask.swift).
    public internal(set) var masks: [PhotoLayer.ID: TiledPixels] = [:]
    /// Brush and eraser paint on the selected layer's mask (PhotoMask.swift).
    public internal(set) var editsMask = false
    /// The crop's aspect lock (PhotoCropTool+Kernel.swift).
    public internal(set) var cropAspect = CropAspect.free
    /// Free Transform in progress (PhotoTransform.swift).
    public internal(set) var transformDraft: TransformDraft?
    /// A drag frame: the routes draw the draft's layer through its matrix at composite time instead of its
    /// resample (`transformPreview(live:)`, PhotoTransform+Kernel.swift). Set on a render's copy, never the document.
    var liveDraft = false
    /// The eyedropper's sample size (PhotoSample+Kernel.swift).
    public internal(set) var sampleSize = SampleSize.point
    /// The Export sheet's last choices (PhotoExportOptions.swift).
    public internal(set) var exportOptions = ExportOptions()
    /// The Export sheet and its write, on the kernel's run (PhotoExportRun+Kernel.swift).
    public internal(set) var exportRun = ExportRun<ExportOptions>.idle
    /// What the open file is, for Save (PhotoDocumentFile.swift).
    public internal(set) var fileKind: PhotoFileKind?
    /// The history step last saved, opened or created (`currentStepID`), so a
    /// new blank image and a just-opened file are clean; nil with no image.
    public internal(set) var savedStepID: Int?
    /// A one-line refusal or note for the status line ("Nothing to paste.");
    /// `clearStatus()` drops it (the window calls it 4 s later).
    public internal(set) var statusMessage: String?
    /// The Type tool's open box on the canvas, nil when none is (PhotoTextBox).
    public internal(set) var textBox: PhotoTextBox?
    /// "Merging…" while Merge Down or Flatten Image works off the main actor (PhotoLayerOps.swift).
    public internal(set) var progress: String?
    /// The file flow's recents, open path and requests for the window (PhotoFileFlow+Kernel.swift).
    public internal(set) var fileFlow = PhotoFileFlowState()
    /// The layer style panel's open section, nil when closed (PhotoStyle+Kernel.swift).
    public internal(set) var stylePanel: StyleKind?
    /// The document's paths and the Pen's view state (PhotoPaths+Kernel.swift).
    var pathState = PhotoPathState()
    /// Test hook: how many times `layerGeometryChanged` ran, and its last call
    /// (PhotoMask.swift). Not part of `==`.
    var geometryChangeCount = 0
    var lastGeometryChange: (id: PhotoLayer.ID, change: LayerGeometryChange)?

    /// The most damage entries kept; a renderer further behind redraws everything.
    static let damageLogLimit = 64

    public init() {}

    /// A workspace on `services`: `.fake` under -PhotoFixture and in tests.
    public init(services: PhotoServices) {
        self.init()
        self.services = services
    }

    /// Why the palette shows `tool` disabled, as its tooltip; nil once it works.
    /// The eyedropper reads the kernel's mean, so it is enabled on any services.
    public func toolHelp(_ tool: PhotoTool) -> String? {
        tool == .eyedropper ? nil : tool.unavailableHelp
    }

    /// Drops the status line's message.
    public mutating func clearStatus() { statusMessage = nil }

    public var selectedLayer: PhotoLayer? {
        layers.first { $0.id == selectedLayerID }
    }

    /// Whether a drag is under way, from its first `drag` to `endDrag`.
    public var isDragging: Bool { stroke != nil }

    /// Whether Delete Layer can run: the last layer can't be removed.
    public var canRemoveLayer: Bool { layers.count > 1 }

    /// Opens a new white image with one "Background" layer, default
    /// adjustments and an empty history. Layer ids keep counting. Throws
    /// `RasterError` for a size CoreRaster rejects; the workspace is unchanged.
    public mutating func newCanvas(width: Int, height: Int) throws {
        let white = try TiledPixels(width: width, height: height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        start(with: white, name: nil)
    }

    /// Replaces the open image with `background` as its one layer.
    mutating func start(with background: TiledPixels, name: String?) {
        canvas = CanvasSize(width: background.width, height: background.height)
        documentName = name
        layers = []
        pixels = [:]
        adjustments = AdjustmentSettings()
        selection = nil
        pendingCrop = nil
        cloneSource = nil
        stroke = nil
        selectionMask = nil
        area = PhotoArea()
        masks = [:]
        editsMask = false
        transformDraft = nil
        pathState = PhotoPathState()
        statusMessage = nil
        fileKind = nil
        history = PhotoHistory()
        // Only an opened file has a name; a new canvas starts unnamed.
        history.baseName = name == nil ? "New Image" : "Open"
        savedStepID = currentStepID
        selectedLayerID = insertLayer(named: "Background", pixels: background, kind: .pixels, at: 0)
        touch(.all)
    }

    /// Selects a layer by id. An unknown id is ignored.
    public mutating func selectLayer(_ id: PhotoLayer.ID) {
        if index(of: id) != nil { selectedLayerID = id }
    }

    /// Picks a tool, dropping any pending crop when it isn't the crop tool.
    public mutating func selectTool(_ tool: PhotoTool) {
        endDrag()
        if tool != .text { commitTextBox() }
        self.tool = tool
        if tool != .crop, pendingCrop != nil { pendingCrop = nil }
    }

    /// The options the panel shows: the eraser's while it is selected,
    /// otherwise the brush's.
    public var toolOptions: ToolOptions { tool == .eraser ? eraserOptions : brushOptions }

    /// The brush cursor's diameter in canvas pixels: the size of the selected
    /// brush, eraser, clone stamp or heal. Nil with no image open or another tool
    /// selected.
    public var brushCursorDiameter: Double? {
        guard canvas != nil, [.brush, .eraser, .clone, .heal].contains(tool) else { return nil }
        return toolOptions.size
    }

    /// Changes one option of the tool the panel shows. A color always goes to
    /// the brush, since the eraser has none.
    public mutating func setToolOption(_ edit: ToolOptionEdit) {
        if case .color = edit {
            brushOptions.apply(edit)
        } else if tool == .eraser {
            eraserOptions.apply(edit)
        } else {
            brushOptions.apply(edit)
        }
    }

    /// Changes one adjustment; AdjustmentSettings clamps and validates it.
    /// A run of changes to one section is one undo step.
    public mutating func adjust(_ edit: AdjustmentEdit) {
        var next = adjustments
        next.apply(edit)
        guard next != adjustments else { return }
        record(.adjustments(adjustments), named: edit.title, coalescing: "adjust-\(edit.section)")
        adjustments = next
        touch(.all, adjustmentsOnly: true)
    }

    /// Adds a transparent, visible, normal-blend layer named "Layer N" (the
    /// lowest N no layer uses) above the selected layer, and selects it.
    /// Ignored with no image open.
    public mutating func addLayer() {
        guard let canvas, let clear = try? TiledPixels(width: canvas.width, height: canvas.height) else { return }
        var number = 1
        while layers.contains(where: { $0.name == "Layer \(number)" }) { number += 1 }
        record(.stack(stackState), named: "New Layer")
        let above = selectedLayerID.flatMap(index(of:)) ?? 0
        selectedLayerID = insertLayer(named: "Layer \(number)", pixels: clear, kind: .pixels, at: above)
        touch(.none)
    }

    /// Removes a layer and selects the one that took its place. Returns false,
    /// changing nothing, for the last layer or an unknown id.
    @discardableResult
    public mutating func removeLayer(_ id: PhotoLayer.ID) -> Bool {
        guard canRemoveLayer, let at = index(of: id) else { return false }
        record(.stack(stackState), named: "Delete Layer")
        layers.remove(at: at)
        pixels[id] = nil
        layerGeometryChanged(id, .removed)
        pruneLayerSelection(near: at)
        touch(.all)
        return true
    }

    /// Renames a layer. Surrounding spaces are dropped; an empty name is ignored.
    public mutating func renameLayer(_ id: PhotoLayer.ID, to name: String) {
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty, let at = index(of: id), layers[at].name != trimmed else { return }
        recordLayers(named: "Rename Layer")
        layers[at].name = trimmed
    }

    // Hide and Show, and Opacity, act on every picked layer when the row is
    // picked: toggleVisibility and setOpacity are in PhotoSeveralLayers+Kernel.

    public mutating func setBlendMode(_ id: PhotoLayer.ID, _ mode: BlendMode) {
        guard let at = index(of: id), layers[at].blendMode != mode else { return }
        recordLayers(named: "Blend Mode")
        layers[at].blendMode = mode
        touch(.all)
    }

    /// Moves the layers at `offsets` (top-first positions) to sit before the
    /// layer now at `destination`, as a list drag reports it; `layers.count`
    /// moves them to the bottom. Out-of-range offsets are ignored. Runs on
    /// LayerTree.move (PhotoLayers+Kernel), and a move that changes nothing
    /// records no step there.
    public mutating func moveLayers(fromOffsets offsets: [Int], toOffset destination: Int) {
        guard (0...layers.count).contains(destination) else { return }
        let sources = Set(offsets.filter { layers.indices.contains($0) })
        commitKernelLayers(
            Self.kernelMoved(layers, fromOffsets: sources, toOffset: destination), named: "Reorder Layers")
    }

    // MARK: Damage

    /// What changed on the canvas since `revision`: `.all` when that is older
    /// than the kept damage, `.none` when nothing did.
    public func damage(since old: Int) -> PhotoDamage {
        guard old < revision else { return .none }
        guard let first = damageLog.first, first.revision <= old + 1 else { return .all }
        return damageLog.filter { $0.revision > old }.reduce(PhotoDamage.none) { $0.union($1.damage) }
    }

    /// Records a change to what the canvas shows; `adjustmentsOnly` when only
    /// the adjustments changed, not the layers or their pixels.
    mutating func touch(_ damage: PhotoDamage, adjustmentsOnly: Bool = false) {
        revision += 1
        if !adjustmentsOnly { contentRevision += 1 }
        damageLog.append((revision, damage))
        if damageLog.count > Self.damageLogLimit { damageLog.removeFirst(damageLog.count - Self.damageLogLimit) }
    }

    /// Folds every revision after `start` into one, `start + 1`, whose damage
    /// covers them all: everything, when the log already dropped some of them.
    mutating func foldRevisions(since start: Int) {
        guard revision > start + 1 else { return }
        let folded = damageLog.filter { $0.revision > start }
        let damage =
            folded.count == revision - start ? folded.reduce(PhotoDamage.none) { $0.union($1.damage) } : .all
        damageLog.removeLast(folded.count)
        revision = start + 1
        damageLog.append((revision, damage))
    }

    // MARK: Helpers

    func index(of id: PhotoLayer.ID) -> Int? {
        layers.firstIndex { $0.id == id }
    }

    /// Where a layer's pixels sit on the canvas.
    func bounds(of layer: PhotoLayer) -> PixelRect? {
        pixels[layer.id].map { PixelRect(x: layer.offsetX, y: layer.offsetY, width: $0.width, height: $0.height) }
    }

    /// Inserts a new default layer of `kind` at `position` and returns its id.
    /// A pixel layer keeps `buffer` in `pixels`; an adjustment layer has none.
    mutating func insertLayer(
        named name: String, pixels buffer: TiledPixels?, kind: PhotoLayerKind, at position: Int
    ) -> PhotoLayer.ID {
        var layer = PhotoLayer(id: "layer-\(nextLayerNumber)", name: name)
        layer.kind = kind
        nextLayerNumber += 1
        layers.insert(layer, at: min(max(position, 0), layers.count))
        if let buffer { pixels[layer.id] = buffer }
        return layer.id
    }

    /// Makes sure no id up to "layer-\(maxID)" is handed out again, so a
    /// loaded document's ids never repeat.
    mutating func reserveLayerIDs(after maxID: Int) {
        if maxID >= nextLayerNumber { nextLayerNumber = maxID + 1 }
    }
}

extension PhotoWorkspace: Equatable {
    /// Equal when they show the same thing in the same state. Two workspaces at
    /// different revisions are never equal, which keeps the comparison from
    /// walking whole pixel buffers when SwiftUI diffs a changed window.
    /// `services` isn't compared: it isn't Equatable and isn't what shows.
    public static func == (lhs: PhotoWorkspace, rhs: PhotoWorkspace) -> Bool {
        lhs.revision == rhs.revision && lhs.canvas == rhs.canvas && lhs.documentName == rhs.documentName
            && lhs.layers == rhs.layers && lhs.layerSelection == rhs.layerSelection && lhs.tool == rhs.tool
            && lhs.brushOptions == rhs.brushOptions
            && lhs.eraserOptions == rhs.eraserOptions && lhs.bucketOptions == rhs.bucketOptions && lhs.adjustments == rhs.adjustments
            && lhs.selection == rhs.selection && lhs.pendingCrop == rhs.pendingCrop
            && lhs.cloneSource == rhs.cloneSource && lhs.stroke == rhs.stroke
            && lhs.history == rhs.history && lhs.selectionMask == rhs.selectionMask && lhs.area == rhs.area
            && lhs.selectionOptions == rhs.selectionOptions && lhs.editsMask == rhs.editsMask
            && lhs.cropAspect == rhs.cropAspect && lhs.transformDraft == rhs.transformDraft
            && lhs.sampleSize == rhs.sampleSize && lhs.exportOptions == rhs.exportOptions
            && lhs.exportRun == rhs.exportRun && lhs.stylePanel == rhs.stylePanel
            && lhs.fileKind == rhs.fileKind && lhs.savedStepID == rhs.savedStepID
            && lhs.statusMessage == rhs.statusMessage && lhs.textBox == rhs.textBox && lhs.progress == rhs.progress && lhs.masks == rhs.masks && lhs.pixels == rhs.pixels
            && lhs.pathState == rhs.pathState
    }
}

extension AdjustmentEdit {
    /// The section this edit changes; nil for tone, which has no AdjustmentKind.
    var kind: AdjustmentKind? {
        switch self {
        case .exposure: .exposure
        case .blackPoint, .whitePoint, .gamma, .gammaField: .levels
        case .curvePoints: .curves
        case .blurSigma: .blur
        case .hue, .saturation, .lightness: .hueSaturation
        case .setEnabled(let kind, _), .reset(let kind): kind
        case .tone: nil
        }
    }

    /// The undo step's name: the section's title, or "Tone".
    var title: String { kind?.title ?? "Tone" }

    /// The key a run of these edits folds under.
    var section: String { kind?.rawValue ?? "tone" }
}

extension AdjustmentKind {
    /// The section's name, as the panel and the Undo item say it.
    public var title: String {
        switch self {
        case .exposure: "Exposure"
        case .levels: "Levels"
        case .curves: "Curves"
        case .blur: "Blur"
        case .hueSaturation: "Hue/Saturation"
        }
    }
}
