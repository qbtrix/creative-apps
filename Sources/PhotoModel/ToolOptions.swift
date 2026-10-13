// ToolOptions.swift: the brush and eraser settings in the Adjust tab's Tool
// options: size in pixels, hardness and opacity as percentages, and the paint
// color as 8-bit sRGB. Every change arrives as one ToolOptionEdit and clamps
// to its range; NaN is ignored. Choosing options is not a document edit, so
// it is not undoable. Linux-safe.
import CoreColor

/// One change the Tool options section can ask for.
public enum ToolOptionEdit: Sendable, Equatable {
    case size(Double)
    case hardness(percent: Double)
    case opacity(percent: Double)
    case color(red: UInt8, green: UInt8, blue: UInt8)
}

public struct ToolOptions: Sendable, Equatable {
    public static let sizeRange: ClosedRange<Double> = 1...500
    /// Hardness and opacity, as the panel shows them.
    public static let hardnessRange: ClosedRange<Double> = 0...100
    public static let opacityRange: ClosedRange<Double> = 1...100

    /// The brush's diameter in pixels.
    public private(set) var size: Double = 20
    /// 100: a hard edge one pixel wide; 0: soft from the center out.
    public private(set) var hardnessPercent: Double = 100
    public private(set) var opacityPercent: Double = 100
    public private(set) var red: UInt8 = 0
    public private(set) var green: UInt8 = 0
    public private(set) var blue: UInt8 = 0

    public init() {}

    public mutating func apply(_ edit: ToolOptionEdit) {
        switch edit {
        case .size(let value): size = Self.clamp(value, to: Self.sizeRange) ?? size
        case .hardness(let value): hardnessPercent = Self.clamp(value, to: Self.hardnessRange) ?? hardnessPercent
        case .opacity(let value): opacityPercent = Self.clamp(value, to: Self.opacityRange) ?? opacityPercent
        case .color(let r, let g, let b): (red, green, blue) = (r, g, b)
        }
    }

    /// The paint color in linear light, as PixelBuffer stores color.
    var linearColor: (r: Float, g: Float, b: Float) {
        let srgb = Color3(Double(red) / 255, Double(green) / 255, Double(blue) / 255)
        // Bytes over 255 are impossible, so the conversion's finiteness check can't fail.
        let linear = (try? srgb.converted(from: .sRGB, to: .linearSRGB)) ?? srgb
        return (Float(linear.c0), Float(linear.c1), Float(linear.c2))
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double? {
        value.isNaN ? nil : min(max(value, range.lowerBound), range.upperBound)
    }
}
