// AdjustKinds.swift (adjust-everywhere AJ-1 stubs, AJ-5 bodies): the adjustment
// kinds beyond AdjustSettings that every app shares, Black & White with its six
// hue weights and Invert, and the five pixel filters with their ranges. Kinds
// compile to CoreRender tone steps after ImagingProgram's: `program` for the GPU
// pass, `adjustments` for the CPU twin. Until AJ-5 both lists are empty.
// Linux-safe.
import CoreRaster
import CoreRender

/// Black & White's six hue weights, percent, -200...300 each.
public struct GrayWeights: Hashable, Codable, Sendable {
    public var red, yellow, green, cyan, blue, magenta: Double

    /// The range every weight keeps.
    public static let range: ClosedRange<Double> = -200...300
    /// 40, 60, 40, 60, 20, 80: core's default mix.
    public static let neutral = GrayWeights(red: 40, yellow: 60, green: 40, cyan: 60, blue: 20, magenta: 80)

    public init(red: Double, yellow: Double, green: Double, cyan: Double, blue: Double, magenta: Double) {
        (self.red, self.yellow, self.green, self.cyan, self.blue, self.magenta) = (red, yellow, green, cyan, blue, magenta)
    }
}

/// An adjustment kind an adjustment layer, a develop setting or a look can carry.
public enum ImagingKind: Hashable, Codable, Sendable {
    case blackAndWhite(GrayWeights), invert

    /// "Black & White", "Invert": the menu item and the undo step.
    public var title: String {
        switch self {
        case .blackAndWhite: "Black & White"
        case .invert: "Invert"
        }
    }
}

/// Kinds compiled to tone steps.
public enum AdjustKinds {
    /// The GPU steps, appended after ImagingProgram's. Stub: empty until AJ-5.
    public static func program(_ kinds: [ImagingKind]) -> [ToneProgram.Operation] { [] }

    /// The CPU twin of `program`. Stub: empty until AJ-5.
    public static func adjustments(_ kinds: [ImagingKind]) -> [ToneAdjustment] { [] }
}

/// A filter that rewrites a pixel layer's pixels.
public enum ImagingFilter: Hashable, Codable, Sendable {
    /// Radius in pixels.
    case gaussianBlur(radius: Double)
    /// Angle in degrees and length in pixels.
    case motionBlur(degrees: Double, distance: Double)
    /// Amount in percent, radius in pixels, threshold in levels.
    case sharpen(amount: Double, radius: Double, threshold: Double)
    /// Strength and detail kept, percent.
    case reduceNoise(strength: Double, detail: Double)
    /// Amount in percent; one value for all three channels when monochrome; the seed repeats a run.
    case addNoise(amount: Double, monochrome: Bool, seed: UInt64)

    public static let blurRadius: ClosedRange<Double> = 0...250
    public static let motionDegrees: ClosedRange<Double> = 0...360
    public static let motionDistance: ClosedRange<Double> = 0...500
    public static let sharpenAmount: ClosedRange<Double> = 0...500
    public static let sharpenRadius: ClosedRange<Double> = 0.1...250
    public static let sharpenThreshold: ClosedRange<Double> = 0...255
    public static let percent: ClosedRange<Double> = 0...100

    /// Every filter's id, in menu order.
    public static let ids = ["gaussian-blur", "motion-blur", "sharpen", "reduce-noise", "add-noise"]

    /// "gaussian-blur": the `filter.<id>` command suffix.
    public var id: String {
        switch self {
        case .gaussianBlur: "gaussian-blur"
        case .motionBlur: "motion-blur"
        case .sharpen: "sharpen"
        case .reduceNoise: "reduce-noise"
        case .addNoise: "add-noise"
        }
    }

    /// "Gaussian Blur": the menu item and the undo step.
    public var title: String {
        switch self {
        case .gaussianBlur: "Gaussian Blur"
        case .motionBlur: "Motion Blur"
        case .sharpen: "Sharpen"
        case .reduceNoise: "Reduce Noise"
        case .addNoise: "Add Noise"
        }
    }

    /// The values a sheet opens on for `id`; nil for an unknown id.
    public static func defaults(_ id: String) -> ImagingFilter? {
        switch id {
        case "gaussian-blur": .gaussianBlur(radius: 2)
        case "motion-blur": .motionBlur(degrees: 0, distance: 10)
        case "sharpen": .sharpen(amount: 100, radius: 1, threshold: 0)
        case "reduce-noise": .reduceNoise(strength: 50, detail: 50)
        case "add-noise": .addNoise(amount: 10, monochrome: false, seed: 0)
        default: nil
        }
    }
}
