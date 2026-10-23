// PhotoBrushKeys+Kernel.swift (brush-keys BK-8): Photo as SuiteKernel's BrushKeyTarget, so `[`, `]`, Shift and the
// digits, Edit > Brush and an agent run the kernel's six BrushKeyCommands. The active brush is the settings of the
// tool the options show, and only with a painting tool (Brush, Eraser, Clone, Heal) on an open image: the eraser keeps
// its own set. With no such tool the digits go to the selected layers' opacity, one undo step for all of them.
// Choosing brush settings is not a document edit. Linux-safe.
import SuiteKernel

extension PhotoWorkspace: BrushKeyTarget {
    /// The tools a brush key acts on: the ones that paint with a brush.
    static let brushKeyTools: Set<PhotoTool> = [.brush, .eraser, .clone, .heal]

    /// The active painting tool's settings; nil with no image or another tool.
    public var activeBrush: BrushSettings? {
        guard canvas != nil, Self.brushKeyTools.contains(tool) else { return nil }
        return toolOptions.settings
    }

    /// Why the selected layers' opacity can't be set: no image, or no layer selected.
    public var layerOpacityHelp: String? {
        canvas == nil ? Self.noImage : (canEditSelectedLayer ? nil : Self.noLayer)
    }

    /// Hands the active tool its new size, hardness and opacity, each through the options' own clamp.
    public mutating func setActiveBrush(_ s: BrushSettings) throws {
        guard activeBrush != nil else { throw CatalogError.unavailable(id: "brush.set", why: BrushKeyCommands.noBrushHelp) }
        setToolOption(.size(s.size))
        setToolOption(.hardness(percent: s.hardness))
        setToolOption(.opacity(percent: s.opacity))
    }

    /// Sets every selected layer to `percent` in one undo step of its own.
    public mutating func setSelectedOpacity(_ percent: Double) throws {
        let id = try selectedID("layer.set-opacity")
        endAdjust(); setOpacity(id, percent: percent); endAdjust()
    }

    /// The options edit a brush key makes; nil for a layer opacity, or a setting the options don't show.
    public static func toolOptionEdit(for action: BrushKeyAction) -> ToolOptionEdit? {
        switch action {
        case .brush(.size(let px)): .size(px)
        case .brush(.hardness(let p)): .hardness(percent: p)
        case .brush(.opacity(let p)): .opacity(percent: p)
        case .brush(.flow), .brush(.spacing), .layerOpacity: nil
        }
    }

    /// What Edit > Brush's step `id` does now: the next size or hardness; nil with no brush tool or another id.
    public func brushStep(_ id: String) -> BrushKeyAction? {
        guard let s = activeBrush else { return nil }
        switch id {
        case "brush.size-up": return .brush(.size(BrushKeys.step(size: s.size, up: true)))
        case "brush.size-down": return .brush(.size(BrushKeys.step(size: s.size, up: false)))
        case "brush.hardness-up": return .brush(.hardness(BrushKeys.hardnessStep(s.hardness, up: true)))
        case "brush.hardness-down": return .brush(.hardness(BrushKeys.hardnessStep(s.hardness, up: false)))
        default: return nil
        }
    }
}
