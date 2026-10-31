// PhotoIntent.swift: everything a person can ask Photo's window to do, as one
// value: every control in the window toolbar, floating tool palette, canvas,
// sidebar, inspector and menus sends one
// of these to PhotoWindow.perform, which calls the matching PhotoWorkspace
// method or opens a panel or sheet. Each v2 area has one case holding its own
// enum, declared in its PhotoWindow+<Area>.swift and routed to that file's
// perform, so a feature adds intents without editing this file; the v1 cases
// stay flat. `confirm` (Return) and `dismiss` (Escape) route by mode.
// PhotoTool's palette look (title, symbol, one-key shortcut) lives here too.
import CoreRaster
import PhotoModel
import SuiteImaging
import SuiteKernel
import SuiteUI
import SwiftUI

enum PhotoIntent {
    case newImage, open, save, saveAs, imageSize
    case openFile(URL)
    case rotate(QuarterTurn)
    /// Image > Flip Canvas: mirrors every layer across the canvas through `image.flip`.
    case flipCanvas(FlipDirection)
    /// Opens the Straighten sheet; `applyStraighten` turns the image by its choices.
    case straighten
    case applyStraighten(degrees: Double, cropToFit: Bool)
    case undo, redo
    case tool(PhotoTool)
    case drag(CGPoint, CGPoint)
    case endDrag
    case toolOption(ToolOptionEdit)
    /// One change to the Paint Bucket's options (PhotoRetouchOptions).
    case bucketOption(BucketOptionEdit)
    /// One GradientEditor gesture on the Gradient tool's fill (PhotoFillToolOptions).
    case gradientOption(GradientIntent)
    case adjust(AdjustmentEdit)
    /// A slider's or the curve's gesture ended: the next adjustment is a new undo step.
    case endAdjust
    case selectAll, deselect, deleteSelection, fillSelection, applyCrop, cancelCrop
    case selectLayer(PhotoLayer.ID)
    /// A Layers row click with its mode (Shift extends, Command toggles); Select > All Layers picks every layer.
    case pickLayer(PhotoLayer.ID, Pick), selectAllLayers
    case toggleVisibility(PhotoLayer.ID)
    /// A gesture in the sidebar's AI tab (SuiteUI AgentActivityList).
    case agent(AgentActivityAction)
    case opacity(PhotoLayer.ID, Double)
    case blendMode(PhotoLayer.ID, CoreRaster.BlendMode)
    case moveLayers(IndexSet, Int)
    case addLayer, deleteLayer, renameLayer, bringForward, sendBackward, selectLayerAbove, selectLayerBelow
    case zoomIn, zoomOut, actualSize, fit
    // One case per v2 area; each area's enum lives in its PhotoWindow+<Area>.swift.
    case file(FileIntent), edit(EditIntent), crop(CropIntent), history(HistoryIntent), select(SelectIntent)
    case adjustmentLayer(AdjustmentLayerIntent), transform(TransformIntent), export(ExportIntent), sample(SampleIntent)
    case place(PhotoPlaceIntent), text(TypeIntent), filter(FilterIntent)
    /// A tone row's change, run as its tone.* command (PhotoWindow+Tone).
    case tone(ToneIntent)
    /// One Pen or point-editor gesture from PhotoPenOverlay, run through the catalog.
    case path(PathIntent)
    /// Return: commits a free transform, else applies a pending crop.
    case confirm
    /// Escape: cancels a free transform, else cancels a pending crop or deselects.
    case dismiss
}

/// Where a view sends its intents.
typealias PhotoPerform = @MainActor (PhotoIntent) -> Void

extension PhotoTool: PaletteTool {
    public var title: String {
        switch self {
        case .select: "Select"
        case .marquee: "Marquee"
        case .ellipse: "Ellipse"
        case .lasso: "Lasso"
        case .polygon: "Polygon Lasso"
        case .wand: "Magic Wand"
        case .brush: "Brush"
        case .eraser: "Eraser"
        case .clone: "Clone"
        case .spotHeal: "Spot Heal"
        case .heal: "Heal"
        case .remove: "Remove"
        case .crop: "Crop"
        case .eyedropper: "Eyedropper"
        case .bucket: "Paint Bucket"
        case .gradient: "Gradient"
        case .text: "Type"
        case .pen: "Pen"
        }
    }

    public var systemImage: String {
        switch self {
        case .select: "cursorarrow.click"
        case .marquee: "rectangle.dashed"
        case .ellipse: "circle.dashed"
        case .lasso: "lasso"
        case .polygon: "hexagon"
        case .wand: "wand.and.stars"
        case .brush: "paintbrush.pointed"
        case .eraser: "eraser"
        case .clone: "square.on.square"
        case .spotHeal: "bandage.fill"
        case .heal: "bandage"
        case .remove: "wand.and.stars"
        case .crop: "crop"
        case .eyedropper: "eyedropper"
        case .bucket: "drop.fill"
        case .gradient: "square.bottomhalf.filled"
        case .text: "textformat"
        case .pen: "pencil.tip"
        }
    }

    public var shortcut: Character? {
        switch self {
        case .select: "v"
        case .marquee: "m"
        case .ellipse, .polygon: nil
        case .lasso: "l"
        case .wand: "w"
        case .brush: "b"
        case .eraser: "e"
        case .clone: "s"
        case .spotHeal: "j"
        case .heal: "j"
        case .remove: "j"
        case .crop: "c"
        case .eyedropper: "i"
        case .bucket: "g"
        case .gradient: "g"
        case .text: "t"
        case .pen: "p"
        }
    }

    /// The pointer over the canvas while this tool is active.
    var pointer: PointerStyle {
        self == .select ? .default : .rectSelection
    }
}
