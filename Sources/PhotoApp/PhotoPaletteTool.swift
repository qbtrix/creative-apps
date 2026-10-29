// PhotoPaletteTool.swift: the tool palette's tool. It carries `model.toolHelp(tool)`
// as its `unavailableHelp`, so the palette shows a tool disabled with the reason
// the workspace's services give, not the tool enum's fallback text. The
// Eyedropper (I) picks through its size chips and the SampleTarget adapter. It
// is enabled on `.fake` and, with the live sampler built (eyedropper PE-5), on
// `.live`: a drag samples the composite into the brush colour. A typed letter
// picks a tool through SuiteUI's ToolKeys; Shift cycles a shared letter.
// PhotoTool's `gesture` (its behaviour class) lives here too.
import PhotoModel
import SuiteUI

struct PhotoPaletteTool: PaletteTool {
    let tool: PhotoTool
    let help: String?

    var title: String { tool.title }
    var systemImage: String { tool.systemImage }
    var unavailableHelp: String? { help }
    var shortcut: Character? { tool.shortcut }
    var gesture: ToolGesture { tool.gesture }
}

extension PhotoTool {
    /// The tool's behaviour class (SuiteUI's ToolGesture), which the gesture contract holds it to.
    public var gesture: ToolGesture {
        switch self {
        case .move: .movesContent
        case .marquee, .ellipse, .lasso, .polygon, .wand, .crop: .selects
        case .brush, .eraser, .clone, .spotHeal, .heal, .remove, .bucket, .gradient: .paints
        case .text: .creates
        case .pen: .editsPoints
        case .eyedropper: .inspects
        }
    }
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

extension PhotoTool {
    /// The tool `characters` pick through SuiteUI's ToolKeys over the palette's faces: one letter, either case, of a
    /// tool `help` leaves enabled; nil for any other text (AC-tools). A shared letter picks the first enabled tool on
    /// it (J Spot Heal, G Paint Bucket); with `cyclingFrom` (Shift held) the next enabled one after that tool, so
    /// Shift-J walks Spot Heal, Heal, Remove and Shift-G Paint Bucket, Gradient (fill-heal FH-3).
    static func picked(
        byTyped characters: String, help: (PhotoTool) -> String?, cyclingFrom current: PhotoTool? = nil
    ) -> PhotoTool? {
        guard characters.count == 1, let key = characters.first else { return nil }
        let tools = allCases.map { PhotoPaletteTool(tool: $0, help: help($0)) }
        let isCurrent: ((PhotoPaletteTool) -> Bool)? = current.map { current in { $0.tool == current } }
        return ToolKeys.tool(forKey: key, in: tools, cyclingFrom: isCurrent)?.tool
    }
}
