// LibraryTool.swift: the loupe's canvas tools on SuiteUI's PaletteTool, so the
// gesture contract (Tests/AppSnapshotTests/GestureContractTests.swift) holds
// Library's canvas drags to the same class budgets as every other app's.
// Library shows no palette: the tool follows the catalog's mode. `.view` is
// the plain loupe, where a drag only gives the canvas its keys (Space-drag,
// scroll and the arrows pan); `.crop` is the loupe while a crop draft is open
// (R, Photo > Crop), where a drag moves the handle under the press or the
// whole frame. The loupe routes its canvas drag by this tool.
import LibraryModel
import SuiteUI

enum LibraryTool: String, CaseIterable, PaletteTool {
    case view, crop

    /// The tool the catalog's mode gives the loupe: `.crop` while a draft is open.
    init(cropping: Bool) { self = cropping ? .crop : .view }

    var title: String { self == .view ? "View" : "Crop" }
    var systemImage: String { self == .view ? "eye" : "crop" }
    var unavailableHelp: String? { nil }
    var shortcut: Character? { self == .crop ? "r" : nil }
    var gesture: ToolGesture { self == .view ? .none : .selects }
}
