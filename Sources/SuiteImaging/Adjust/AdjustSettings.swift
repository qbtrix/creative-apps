// AdjustSettings.swift: the one adjustment value Photo's Adjust panel and
// Library's develop panel share (suite-imaging IM-2 stubs, IM-3 bodies):
// exposure, levels, a tone curve and hue/saturation, in the units CoreRender's
// `ToneAdjustment` takes. IM-2 declares the shapes and neutral values only:
// `clamped()` and the curve repair return their input, and Codable is the
// synthesized form until IM-3 reads Photo's percent keys and Library's keys.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Input and output levels on sRGB-encoded values 0...1, gamma 0.1...9.99.
/// Library's 0...255 keys and Photo's percent keys both decode into it; it
/// encodes Library's keys (IM-3).
public struct AdjustLevels: Hashable, Sendable, Codable {
    public var inputBlack, inputWhite, gamma, outputBlack, outputWhite: Double

    /// Black 0, white 1, gamma 1 both ways: the picture unchanged.
    public static let neutral = AdjustLevels(inputBlack: 0, inputWhite: 1, gamma: 1, outputBlack: 0, outputWhite: 1)

    public init(inputBlack: Double, inputWhite: Double, gamma: Double, outputBlack: Double, outputWhite: Double) {
        self.inputBlack = inputBlack
        self.inputWhite = inputWhite
        self.gamma = gamma
        self.outputBlack = outputBlack
        self.outputWhite = outputWhite
    }

    /// Every value in range, with a gap of 1/255 between input black and
    /// white. Stub: returns `self` until IM-3.
    public func clamped() -> AdjustLevels { self }
}

/// One curve point, both coordinates sRGB-encoded values in 0...1.
public struct AdjustCurvePoint: Hashable, Sendable, Codable {
    public var x, y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A monotone curve over sRGB values, 2 to 16 points, sorted, clamped to
/// 0...1, points closer than `minGap` dropped (Library's rule); Photo's
/// whole-list refusal becomes this repair (IM-3). Stub: keeps the points as given.
public struct AdjustCurve: Hashable, Sendable, Codable {
    /// The smallest x gap two kept points may have.
    public static let minGap: Double = 1.0 / 255
    /// The most points a curve keeps.
    public static let maxPoints = 16
    public private(set) var points: [AdjustCurvePoint]

    public init(points: [AdjustCurvePoint]) {
        self.points = points
    }

    /// (0, 0) to (1, 1): the picture unchanged.
    public static let identity = AdjustCurve(points: [AdjustCurvePoint(x: 0, y: 0), AdjustCurvePoint(x: 1, y: 1)])
}

/// CoreRender's `hueSaturation` units: hue in degrees -180...180, saturation
/// and lightness -100...100.
public struct AdjustHueSaturation: Hashable, Sendable, Codable {
    public var hue, saturation, lightness: Double

    public static let neutral = AdjustHueSaturation(hue: 0, saturation: 0, lightness: 0)

    public init(hue: Double, saturation: Double, lightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }
}

/// The whole adjustment: exposure in stops (-5...5), levels, curve and
/// hue/saturation. ImagingProgram compiles it to tone steps.
public struct AdjustSettings: Hashable, Sendable, Codable {
    public var exposure: Double
    public var levels: AdjustLevels
    public var curve: AdjustCurve
    public var hueSaturation: AdjustHueSaturation

    public static let neutral = AdjustSettings()

    public init(exposure: Double = 0, levels: AdjustLevels = .neutral, curve: AdjustCurve = .identity,
                hueSaturation: AdjustHueSaturation = .neutral) {
        self.exposure = exposure
        self.levels = levels
        self.curve = curve
        self.hueSaturation = hueSaturation
    }

    /// True when no part changes the picture.
    public var isNeutral: Bool { self == .neutral }
}
