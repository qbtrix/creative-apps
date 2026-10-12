// AdjustmentSettings.swift: the values behind Photo's adjustments inspector:
// exposure, levels, blur and hue/saturation, each with an enable switch.
// Exposure and levels are Float like CoreRaster's parameters; sigma is Double.
// Every change arrives as one AdjustmentEdit: values clamp to their range, NaN
// is ignored, and a black point at or above the white point (or the reverse)
// is refused, keeping the old value. The canvas doesn't read these yet; the
// CoreRaster wiring comes later. Linux-safe.

/// One adjustment section in the inspector.
public enum AdjustmentKind: String, CaseIterable, Sendable {
    case exposure, levels, blur, hueSaturation
}

/// One change the inspector can ask for.
public enum AdjustmentEdit: Sendable, Equatable {
    case exposure(Float)
    case blackPoint(Float)
    case whitePoint(Float)
    case gamma(Float)
    case blurSigma(Double)
    case hue(Double)
    case saturation(Double)
    case lightness(Double)
    case setEnabled(AdjustmentKind, Bool)
    /// Puts a section's values back to their defaults; its switch stays.
    case reset(AdjustmentKind)
}

public struct AdjustmentSettings: Sendable, Equatable {
    public static let exposureRange: ClosedRange<Float> = -5...5
    public static let levelsRange: ClosedRange<Float> = 0...1
    public static let gammaRange: ClosedRange<Float> = 0.1...10
    public static let sigmaRange: ClosedRange<Double> = 0...100
    public static let hueRange: ClosedRange<Double> = -180...180
    /// Saturation and lightness.
    public static let percentRange: ClosedRange<Double> = -100...100

    /// Stops.
    public private(set) var exposure: Float = 0
    public private(set) var blackPoint: Float = 0
    public private(set) var whitePoint: Float = 1
    public private(set) var gamma: Float = 1
    /// Gaussian blur radius in pixels.
    public private(set) var blurSigma: Double = 0
    /// Degrees.
    public private(set) var hue: Double = 0
    public private(set) var saturation: Double = 0
    public private(set) var lightness: Double = 0
    public private(set) var enabled: Set<AdjustmentKind> = Set(AdjustmentKind.allCases)

    public init() {}

    public func isEnabled(_ kind: AdjustmentKind) -> Bool { enabled.contains(kind) }

    /// Whether a section's values leave the image as it is.
    public func isIdentity(_ kind: AdjustmentKind) -> Bool {
        var defaults = self
        defaults.reset(kind)
        return defaults == self
    }

    /// True when no enabled section changes the image.
    public var isIdentity: Bool {
        AdjustmentKind.allCases.allSatisfy { !isEnabled($0) || isIdentity($0) }
    }

    public mutating func apply(_ edit: AdjustmentEdit) {
        switch edit {
        case .exposure(let value):
            exposure = Self.clamp(value, to: Self.exposureRange) ?? exposure
        case .blackPoint(let value):
            if let value = Self.clamp(value, to: Self.levelsRange), value < whitePoint { blackPoint = value }
        case .whitePoint(let value):
            if let value = Self.clamp(value, to: Self.levelsRange), value > blackPoint { whitePoint = value }
        case .gamma(let value):
            gamma = Self.clamp(value, to: Self.gammaRange) ?? gamma
        case .blurSigma(let value):
            blurSigma = Self.clamp(value, to: Self.sigmaRange) ?? blurSigma
        case .hue(let value):
            hue = Self.clamp(value, to: Self.hueRange) ?? hue
        case .saturation(let value):
            saturation = Self.clamp(value, to: Self.percentRange) ?? saturation
        case .lightness(let value):
            lightness = Self.clamp(value, to: Self.percentRange) ?? lightness
        case .setEnabled(let kind, let isOn):
            if isOn { enabled.insert(kind) } else { enabled.remove(kind) }
        case .reset(let kind):
            reset(kind)
        }
    }

    private mutating func reset(_ kind: AdjustmentKind) {
        let defaults = AdjustmentSettings()
        switch kind {
        case .exposure:
            exposure = defaults.exposure
        case .levels:
            blackPoint = defaults.blackPoint
            whitePoint = defaults.whitePoint
            gamma = defaults.gamma
        case .blur:
            blurSigma = defaults.blurSigma
        case .hueSaturation:
            hue = defaults.hue
            saturation = defaults.saturation
            lightness = defaults.lightness
        }
    }

    /// `value` inside `range`, or nil for NaN.
    private static func clamp<Value: BinaryFloatingPoint>(_ value: Value, to range: ClosedRange<Value>) -> Value? {
        value.isNaN ? nil : min(max(value, range.lowerBound), range.upperBound)
    }
}
