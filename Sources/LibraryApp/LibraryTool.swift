// LibraryTool.swift: the loupe's canvas tools as palette tools, so Library
// declares each one's ToolGesture like every app and the gesture contract
// (Tests/AppSnapshotTests/GestureContractTests.swift) holds it to its class.
// Library shows no palette: the loupe's mode picks the tool. Outside crop
// mode a canvas drag only gives the canvas the keys (View); while a crop
// draft is open (Photo ▸ Crop, R) it moves the crop handle under the press,
// or the whole frame (Crop).
import SuiteUI

/// The loupe's canvas tools: View outside crop mode, Crop while a draft is open.
enum LibraryTool: String, CaseIterable, PaletteTool {
    case view, crop
    var title: String { self == .view ? "View" : "Crop" }
    var systemImage: String { self == .view ? "eye" : "crop" }
    var unavailableHelp: String? { nil }
    var gesture: ToolGesture { self == .view ? .none : .selects }

    /// The tool a loupe drag uses: Crop while a crop draft is open.
    static func current(cropping: Bool) -> LibraryTool { cropping ? .crop : .view }
}
