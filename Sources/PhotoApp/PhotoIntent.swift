// PhotoIntent.swift: everything a person can ask Photo's window to do, as one
// value: every control in the top bar, rail, canvas, panel and menus sends one
// of these to PhotoWindow.perform, which calls the matching PhotoWorkspace
// method or opens a panel or sheet. PhotoTool's rail look (title, symbol,
// one-key shortcut) lives here too.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

enum PhotoIntent {
    case newImage, open, save, saveAs, export, imageSize
    case openFile(URL)
    case rotate(QuarterTurn)
    /// Opens the Straighten sheet; `applyStraighten` turns the image by its choices.
    case straighten
    case applyStraighten(degrees: Double, cropToFit: Bool)
    case undo, redo
    case tool(PhotoTool)
    case drag(CGPoint, CGPoint)
    case endDrag
    case toolOption(ToolOptionEdit)
    case adjust(AdjustmentEdit)
    /// A slider's or the curve's gesture ended: the next adjustment is a new undo step.
    case endAdjust
    case selectAll, deselect, deleteSelection, fillSelection, applyCrop, cancelCrop
    case selectLayer(PhotoLayer.ID)
    case toggleVisibility(PhotoLayer.ID)
    case opacity(PhotoLayer.ID, Double)
    case blendMode(PhotoLayer.ID, CoreRaster.BlendMode)
    case moveLayers(IndexSet, Int)
    case addLayer, deleteLayer, renameLayer, bringForward, sendBackward, selectLayerAbove, selectLayerBelow
    case zoomIn, zoomOut, actualSize, fit
}

/// Where a view sends its intents.
typealias PhotoPerform = @MainActor (PhotoIntent) -> Void

extension PhotoTool: PaletteTool {
    public var title: String {
        switch self {
        case .move: "Move"
        case .marquee: "Marquee"
        case .brush: "Brush"
        case .eraser: "Eraser"
        case .crop: "Crop"
        }
    }

    public var systemImage: String {
        switch self {
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .marquee: "rectangle.dashed"
        case .brush: "paintbrush.pointed"
        case .eraser: "eraser"
        case .crop: "crop"
        }
    }

    public var shortcut: Character? {
        switch self {
        case .move: "v"
        case .marquee: "m"
        case .brush: "b"
        case .eraser: "e"
        case .crop: "c"
        }
    }

    /// The pointer over the canvas while this tool is active.
    var pointer: PointerStyle {
        self == .move ? .grabIdle : .rectSelection
    }
}
