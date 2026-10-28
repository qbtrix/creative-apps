// PhotoFacets.swift: PhotoWorkspace cut into the facets a Photo window
// publishes (the AppKit window shell plan, slice 1). Each facet is a small
// Equatable value; the app's PhotoSession keeps one observable box per facet
// and, after every edit, re-derives `facets` and writes only the boxes whose
// value changed, so a view re-runs only for the facets its body reads.
//
// Every stored field of PhotoWorkspace belongs to exactly one facet
// (`PhotoWorkspace.facetFields`; PhotoFacetsTests checks the table against the
// struct's fields, so a new field fails until it is placed). A field is
// carried either as itself or, where comparing it would walk pixels, through
// the counter that moves with it: `pixels`, `masks` and `damageLog` through
// `revision` (which goes up with every change to what the canvas shows), the
// history's edits through its step names, index and ids, `services` through
// `isPreviewData`. The geometry hooks are tests' counters and never show.
//
// `toolOptions` is the one facet a window body doesn't read: a brush-size
// step re-runs only the views that show options (the inspector, the canvas
// overlay's brush cursor). The doc's single `tool` facet is split in two for
// that, since the window must still follow which tool is picked (its palette,
// pointer and menus). Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

/// A facet of a Photo window's state.
public enum PhotoFacet: String, CaseIterable, Sendable {
    case document, tool, toolOptions, adjust, history, status, canvas, file
}

/// Every facet of a workspace, derived by `PhotoWorkspace.facets`.
public struct PhotoFacets: Equatable, Sendable {
    /// The image's size, name and layer stack, and the picked layers.
    public struct Document: Equatable, Sendable {
        public let canvas: CanvasSize?
        public let resolution: Double
        public let documentName: String?
        public let layers: [PhotoLayer]
        let layerSelection: Selection<PhotoLayer.ID>
        let nextLayerNumber: Int
        public let editsMask: Bool
    }

    /// Which tool is picked, and the crop tool's aspect lock (menus and the canvas read both).
    public struct Tool: Equatable, Sendable {
        public let tool: PhotoTool
        public let cropAspect: CropAspect
    }

    /// The options only the inspector's option rows and the canvas overlay show.
    public struct ToolOptions: Equatable, Sendable {
        public let brush: PhotoModel.ToolOptions
        public let eraser: PhotoModel.ToolOptions
        public let bucket: BucketOptions
        public let area: PhotoAreaOptions
        public let selection: SelectionOptions
        public let sampleSize: SampleSize
    }

    /// The image adjustments and the open layer style section.
    public struct Adjust: Equatable, Sendable {
        public let adjustments: AdjustmentSettings
        public let stylePanel: StyleKind?
    }

    /// The undo history as the History tab and the Edit menu show it, and the saved step.
    public struct History: Equatable, Sendable {
        public let steps: [String]
        public let index: Int
        public let currentStepID: Int
        let runKey: String?
        public let savedStepID: Int?
    }

    /// The status line's message and the off-main-actor work note.
    public struct Status: Equatable, Sendable {
        public let message: String?
        public let progress: String?
    }

    /// What the canvas draws over and under the picture; `revision` first, so a changed picture compares at once.
    public struct Canvas: Equatable, Sendable {
        public let revision: Int
        let contentRevision: Int
        public let selection: PixelRect?
        let selectionMask: Mask?
        let area: PhotoArea
        let areaCorners: [Mask.Point]
        public let pendingCrop: PixelRect?
        public let cloneSource: CloneSource?
        let stroke: PhotoStroke?
        public let transformDraft: TransformDraft?
        let liveDraft: Bool
        public let textBox: PhotoTextBox?
        let pathState: PhotoPathState
    }

    /// The open file, the shared recents and requests, and Export's choices and run.
    public struct File: Equatable, Sendable {
        public let isPreviewData: Bool
        public let fileKind: PhotoFileKind?
        public let recents: [RecentFileEntry]
        public let documentPath: String?
        let requests: [PhotoFileRequest]
        public let exportOptions: ExportOptions
        public let exportRun: ExportRun<ExportOptions>
    }

    public let document: Document
    public let tool: Tool
    public let toolOptions: ToolOptions
    public let adjust: Adjust
    public let history: History
    public let status: Status
    public let canvas: Canvas
    public let file: File
}

extension PhotoFacets {
    /// Equal in every facet but `facet`: what a view that shows nothing of that facet compares to skip a re-run.
    public func equal(to other: PhotoFacets, except facet: PhotoFacet) -> Bool {
        PhotoFacet.allCases.allSatisfy { $0 == facet || same($0, other) }
    }

    private func same(_ facet: PhotoFacet, _ other: PhotoFacets) -> Bool {
        switch facet {
        case .document: document == other.document
        case .tool: tool == other.tool
        case .toolOptions: toolOptions == other.toolOptions
        case .adjust: adjust == other.adjust
        case .history: history == other.history
        case .status: status == other.status
        case .canvas: canvas == other.canvas
        case .file: file == other.file
        }
    }
}

extension PhotoWorkspace {
    /// Each stored field's facet. Every field is in exactly one list (PhotoFacetsTests).
    public static let facetFields: [PhotoFacet: [String]] = [
        .document: ["canvas", "resolution", "documentName", "layers", "layerSelection", "nextLayerNumber", "editsMask"],
        .tool: ["tool", "cropAspect"],
        .toolOptions: ["brushOptions", "eraserOptions", "bucketOptions", "areaOptions", "selectionOptions", "sampleSize"],
        .adjust: ["adjustments", "stylePanel"],
        .history: ["history", "savedStepID"],
        .status: ["statusMessage", "progress"],
        .canvas: [
            "revision", "contentRevision", "damageLog", "pixels", "masks", "selection", "selectionMask", "maskOutline",
            "area", "areaCorners", "pendingCrop", "cloneSource", "stroke", "transformDraft", "liveDraft", "textBox",
            "pathState", "geometryChangeCount", "lastGeometryChange",
        ],
        .file: ["services", "fileKind", "fileFlow", "exportOptions", "exportRun"],
    ]

    /// The workspace as its facets.
    public var facets: PhotoFacets {
        PhotoFacets(
            document: .init(
                canvas: canvas, resolution: resolution, documentName: documentName, layers: layers,
                layerSelection: layerSelection, nextLayerNumber: nextLayerNumber, editsMask: editsMask),
            tool: .init(tool: tool, cropAspect: cropAspect),
            toolOptions: .init(
                brush: brushOptions, eraser: eraserOptions, bucket: bucketOptions, area: areaOptions,
                selection: selectionOptions, sampleSize: sampleSize),
            adjust: .init(adjustments: adjustments, stylePanel: stylePanel),
            history: .init(
                steps: historySteps, index: historyIndex, currentStepID: currentStepID, runKey: history.runKey,
                savedStepID: savedStepID),
            status: .init(message: statusMessage, progress: progress),
            canvas: .init(
                revision: revision, contentRevision: contentRevision, selection: selection, selectionMask: selectionMask,
                area: area, areaCorners: areaCorners, pendingCrop: pendingCrop, cloneSource: cloneSource, stroke: stroke,
                transformDraft: transformDraft, liveDraft: liveDraft, textBox: textBox, pathState: pathState),
            file: .init(
                isPreviewData: isPreviewData, fileKind: fileKind, recents: fileFlow.recents,
                documentPath: fileFlow.documentPath, requests: fileFlow.requests, exportOptions: exportOptions,
                exportRun: exportRun))
    }
}
