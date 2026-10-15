// PhotoRailTool.swift: the tool rail's tool. It carries `model.toolHelp(tool)`
// as its `unavailableHelp`, so the rail shows a tool disabled with the reason
// the workspace's services give (the Eyedropper is "Not built yet (PV-9)." on
// `.live` and enabled on `.fake`), not the tool enum's fallback text.
import PhotoModel
import SuiteUI

struct PhotoRailTool: PaletteTool {
    let tool: PhotoTool
    let help: String?

    var title: String { tool.title }
    var systemImage: String { tool.systemImage }
    var unavailableHelp: String? { help }
    var shortcut: Character? { tool.shortcut }
}

extension PhotoRailTool {
    /// `tool` with the help `model` gives it.
    init(_ tool: PhotoTool, in model: PhotoWorkspace) {
        self.init(tool: tool, help: model.toolHelp(tool))
    }

    /// Every tool, in rail order, as `model` enables it.
    static func rail(_ model: PhotoWorkspace) -> [PhotoRailTool] {
        PhotoTool.allCases.map { PhotoRailTool($0, in: model) }
    }
}
