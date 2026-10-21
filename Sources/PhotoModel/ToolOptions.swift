// ToolOptions.swift: the brush's or the eraser's settings in the inspector's
// Tool options (PhotoWorkspace keeps one set per tool, two kernel
// `BrushSettings` values): size in pixels, hardness and opacity as
// percentages, the paint color as 8-bit sRGB, and the Gradient tool's kernel
// `Fill` (kept in the brush's set, which the panel shows for it). Every change arrives as one
// ToolOptionEdit, goes to the settings as `BrushEdit`s (PhotoBrush+Kernel.swift)
// and clamps to its range; NaN is ignored. A gradient edit is one editor
// `GradientIntent`, run through the kernel's `GradientRules` (PG-4): the type
// is linear or radial only and the angle is ignored, since the drag gives the
// line. Choosing options is not a document edit, so it is not undoable.
// Linux-safe.
import CoreColor
import FlareCore
import SuiteKernel

/// One change the Tool options section can ask for.
public enum ToolOptionEdit: Sendable, Equatable {
    case size(Double)
    case hardness(percent: Double)
    case opacity(percent: Double)
    case color(red: UInt8, green: UInt8, blue: UInt8)
    /// One of `ToolOptions.presets`: all its settings at once; the color stays.
    case preset(BrushPreset)
    /// One gesture of the Gradient tool's stop editor (`runGradientOption`).
    case gradient(GradientIntent)
}

public struct ToolOptions: Sendable, Equatable {
    public static let sizeRange: ClosedRange<Double> = BrushSettings.ranges.size
    /// Hardness and opacity, as the panel shows them.
    public static let hardnessRange: ClosedRange<Double> = BrushSettings.ranges.percent
    public static let opacityRange: ClosedRange<Double> = 1...100

    /// The kernel's settings: size, hardness, opacity, flow and spacing (the
    /// clone stamp's dab gap, of the size).
    public private(set) var settings = BrushSettings()
    /// The brush's diameter in pixels.
    public var size: Double { settings.size }
    /// 100: a hard edge one pixel wide; 0: soft from the center out.
    public var hardnessPercent: Double { settings.hardness }
    public var opacityPercent: Double { settings.opacity }
    public private(set) var red: UInt8 = 0
    public private(set) var green: UInt8 = 0
    public private(set) var blue: UInt8 = 0
    /// The Gradient tool's stops and type, the kernel's `Fill` (rule 20: no
    /// Photo gradient type); edited by `runGradientOption` (PG-4). Its points
    /// are a unit box's; a drag gives the real line. Written only through
    /// `setGradient`.
    public private(set) var gradient: Fill = ToolOptions.defaultGradient

    /// Black to white, linear, left to right.
    public static let defaultGradient = Fill.linear(
        stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
        start: Point(x: 0, y: 0), end: Point(x: 1, y: 0))

    public init() {}

    public mutating func apply(_ edit: ToolOptionEdit) {
        if case .color(let r, let g, let b) = edit { (red, green, blue) = (r, g, b) }
        if case .gradient(let intent) = edit { runGradient(intent) }
        for brushEdit in Self.brushEdits(edit) { _ = settings.apply(brushEdit) }
    }

    /// Replaces the Gradient tool's `Fill`: the one writer of `gradient`,
    /// for `runGradientOption` once `GradientRules` has edited it (PG-4).
    mutating func setGradient(_ fill: Fill) { gradient = fill }

    /// The box the tool's `gradient` points live in until a drag maps them.
    static let unitBox = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)

    /// One editor gesture on `gradient` through `GradientRules`. The tool
    /// draws only linear and radial gradients, so a switch to solid is
    /// ignored; it has no angle (a drag gives the line), so an angle is too.
    /// A rule that can't apply (a removal at two stops, a bad
    /// index, the stop cap) leaves the gradient as it was.
    mutating func runGradient(_ intent: GradientIntent) {
        switch intent {
        case .type(let type):
            guard type != .solid else { return }
            setGradient(GradientRules.converted(gradient, to: type, in: Self.unitBox))
        case .add(let offset):
            setGradient(GradientRules.addingStop(gradient, at: offset)?.fill ?? gradient)
        case .move(let index, let offset, _):
            setGradient(GradientRules.movingStop(gradient, index: index, to: offset).fill)
        case .remove(let index):
            setGradient(GradientRules.removingStop(gradient, index: index) ?? gradient)
        case .color(let index, let color, _):
            setGradient(GradientRules.recoloring(gradient, index: index, to: color))
        case .angle:
            break
        }
    }

    /// The paint color in linear light, as PixelBuffer stores color.
    var linearColor: (r: Float, g: Float, b: Float) {
        let srgb = Color3(Double(red) / 255, Double(green) / 255, Double(blue) / 255)
        // Bytes over 255 are impossible, so the conversion's finiteness check can't fail.
        let linear = (try? srgb.converted(from: .sRGB, to: .linearSRGB)) ?? srgb
        return (Float(linear.c0), Float(linear.c1), Float(linear.c2))
    }
}
