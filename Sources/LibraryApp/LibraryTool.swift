// LibraryTool.swift: the loupe's canvas tools, so Library declares each tool's
// ToolGesture like every app (GestureContractTests). The loupe has no tool
// palette: a plain drag only gives the canvas focus (it pans on Space-drag and
// scroll), and Crop (R or Photo > Crop) is a mode whose drag moves the crop
// frame's handle under the press, or the whole frame. The loupe reads its
// tool from whether a crop draft is open.
import SuiteUI

/// The loupe's canvas tools: the plain view, and Crop while a draft is open.
enum LibraryTool: String, CaseIterable, PaletteTool {
    case view, crop
    var title: String { self == .view ? "View" : "Crop" }
    var systemImage: String { self == .view ? "hand.raised" : "crop" }
    var unavailableHelp: String? { nil }
    var shortcut: Character? { self == .crop ? "r" : nil }
    var gesture: ToolGesture { self == .view ? .none : .selects }
}
