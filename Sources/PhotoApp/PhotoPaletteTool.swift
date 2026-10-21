// PhotoPaletteTool.swift: the tool palette's tool. It carries `model.toolHelp(tool)`
// as its `unavailableHelp`, so the palette shows a tool disabled with the reason
// the workspace's services give, not the tool enum's fallback text. The
// Eyedropper (I) is enabled on `.fake`, where it picks through its size chips
// and the SampleTarget adapter; on `.live` it stays "Not built yet (PV-9)."
// until the live sampler lands (eyedropper PE-5).
import PhotoModel
import SuiteUI

struct PhotoPaletteTool: PaletteTool {
    let tool: PhotoTool
    let help: String?

    var title: String { tool.title }
    var systemImage: String { tool.systemImage }
    var unavailableHelp: String? { help }
    var shortcut: Character? { tool.shortcut }
}

extension PhotoPaletteTool {
    /// `tool` with the help `model` gives it.
    init(_ tool: PhotoTool, in model: PhotoWorkspace) {
        self.init(tool: tool, help: model.toolHelp(tool))
    }

    /// Every tool, in palette order, as `model` enables it.
    static func palette(_ model: PhotoWorkspace) -> [PhotoPaletteTool] {
        PhotoTool.allCases.map { PhotoPaletteTool($0, in: model) }
    }
}
