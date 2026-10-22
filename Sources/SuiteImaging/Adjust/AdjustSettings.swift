// AdjustSettings.swift: the one adjustment value Photo's Adjust panel and
// Library's develop panel share (suite-imaging IM-2 stubs, IM-3 bodies):
// exposure, levels, a tone curve and hue/saturation, in the units CoreRender's
// `ToneAdjustment` takes. Every value is kept in range: `clamped()` for levels
// and hue/saturation, the curve's repair in `init(points:)`, and decoding goes
// through them, so a damaged file can't reach the renderer. Levels decode
// Library's stored keys (`inBlack`...`outWhite`, 0...1), Photo's stored keys
// (`blackPoint`, `whitePoint`, 0...1), Photo's percent keys (`blackPercent`,
// `whitePercent`, /100) and Library's 0...255 row keys (`black`, `white`,
// `outputBlack`, `outputWhite`, /255), the first found winning in that order;
// they encode Library's stored keys. Settings encode only their non-neutral
// parts, so neutral is `{}`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Input and output levels on sRGB-encoded values 0...1, gamma 0.1...9.99.
/// Library's 0...255 keys and Photo's percent keys both decode into it; it
/// encodes Library's keys.
public struct AdjustLevels: Hashable, Sendable, Codable {
    public var inputBlack, inputWhite, gamma, outputBlack, outputWhite: Double

    /// Black 0, white 1, gamma 1 both ways: the picture unchanged.
    public static let neutral = AdjustLevels(inputBlack: 0, inputWhite: 1, gamma: 1, outputBlack: 0, outputWhite: 1)
    /// Library's range; Photo's old ceiling of 10 clamps to 9.99, a change no one can see.
    public static let gammaRange: ClosedRange<Double> = 0.1...9.99
    /// The least gap between input black and white: one byte level.
    public static let pointGap = 1.0 / 255

    public init(inputBlack: Double, inputWhite: Double, gamma: Double, outputBlack: Double, outputWhite: Double) {
        self.inputBlack = inputBlack
        self.inputWhite = inputWhite
        self.gamma = gamma
        self.outputBlack = outputBlack
        self.outputWhite = outputWhite
    }

    /// Every value in range, NaN or infinity giving the neutral value. White
    /// is placed first, at least `pointGap` up, then black at least `pointGap`
    /// below it (the order Library's decoder sets them in).
    public func clamped() -> AdjustLevels {
        let n = Self.neutral
        let white = Self.clamp(inputWhite, n.inputWhite, Self.pointGap...1)
        return AdjustLevels(inputBlack: Self.clamp(inputBlack, n.inputBlack, 0...(white - Self.pointGap)),
                            inputWhite: white,
                            gamma: Self.clamp(gamma, n.gamma, Self.gammaRange),
                            outputBlack: Self.clamp(outputBlack, n.outputBlack, 0...1),
                            outputWhite: Self.clamp(outputWhite, n.outputWhite, 0...1))
    }

    /// `value` inside `range`, or `neutral` when it isn't finite.
    static func clamp(_ value: Double, _ neutral: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : neutral
    }

    private enum CodingKeys: String, CodingKey {
        /// Library's stored keys, 0...1: the encoded form.
        case inBlack, inWhite, gamma, outBlack, outWhite
        /// Photo's stored keys, 0...1.
        case blackPoint, whitePoint
        /// Photo's percent keys, 0...100.
        case blackPercent, whitePercent
        /// Library's row keys, 0...255.
        case black, white, outputBlack, outputWhite
    }

    /// The first present key of `keys`, divided by its scale, or `fallback`.
    private static func read(_ c: KeyedDecodingContainer<CodingKeys>, _ keys: [(CodingKeys, Double)],
                             _ fallback: Double) throws -> Double {
        for (key, scale) in keys {
            if let value = try c.decodeIfPresent(Double.self, forKey: key) { return value / scale }
        }
        return fallback
    }

    /// Any of the four key sets, read back in range.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let n = Self.neutral
        let percent = 100.0, byte = 255.0
        self = AdjustLevels(
            inputBlack: try Self.read(c, [(.inBlack, 1), (.blackPoint, 1), (.blackPercent, percent), (.black, byte)], n.inputBlack),
            inputWhite: try Self.read(c, [(.inWhite, 1), (.whitePoint, 1), (.whitePercent, percent), (.white, byte)], n.inputWhite),
            gamma: try Self.read(c, [(.gamma, 1)], n.gamma),
            outputBlack: try Self.read(c, [(.outBlack, 1), (.outputBlack, byte)], n.outputBlack),
            outputWhite: try Self.read(c, [(.outWhite, 1), (.outputWhite, byte)], n.outputWhite)
        ).clamped()
    }

    /// Library's keys, all five, as its catalog writes them.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(inputBlack, forKey: .inBlack)
        try c.encode(inputWhite, forKey: .inWhite)
        try c.encode(gamma, forKey: .gamma)
        try c.encode(outputBlack, forKey: .outBlack)
        try c.encode(outputWhite, forKey: .outWhite)
    }
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
/// whole-list refusal becomes this repair.
public struct AdjustCurve: Hashable, Sendable, Codable {
    /// The smallest x gap two kept points may have.
    public static let minGap: Double = 1.0 / 255
    /// The most points a curve keeps.
    public static let maxPoints = 16
    public private(set) var points: [AdjustCurvePoint]

    /// The repair. A point with a NaN or infinite coordinate is refused; the
    /// rest are clamped to 0...1 and sorted by x. The first and last stay; an
    /// inner point closer than `minGap` in x to the kept one before it, or to
    /// the last, merges into it (is dropped); at most `maxPoints` stay, the
    /// last among them. Fewer than 2 points, or ends closer than `minGap`,
    /// give the identity.
    public init(points: [AdjustCurvePoint]) {
        let sorted = points.filter { $0.x.isFinite && $0.y.isFinite }
            .map { AdjustCurvePoint(x: min(max($0.x, 0), 1), y: min(max($0.y, 0), 1)) }
            .sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        guard let first = sorted.first, let last = sorted.last, last.x - first.x >= Self.minGap else {
            self.points = Self.identityPoints
            return
        }
        var kept = [first]
        for point in sorted.dropFirst().dropLast() {
            guard let previous = kept.last else { continue }
            let nearPrevious = point.x - previous.x < Self.minGap
            if !nearPrevious && last.x - point.x >= Self.minGap { kept.append(point) }
        }
        self.points = Array(kept.prefix(Self.maxPoints - 1)) + [last]
    }

    private static let identityPoints = [AdjustCurvePoint(x: 0, y: 0), AdjustCurvePoint(x: 1, y: 1)]

    /// (0, 0) to (1, 1): the picture unchanged.
    public static let identity = AdjustCurve(points: identityPoints)

    private enum CodingKeys: String, CodingKey { case points }

    /// `{"points": [...]}`, Library's form, repaired as it is read; no points is the identity.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(points: try c.decodeIfPresent([AdjustCurvePoint].self, forKey: .points) ?? Self.identityPoints)
    }
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

    /// Every value in range; NaN or infinity gives 0.
    public func clamped() -> AdjustHueSaturation {
        AdjustHueSaturation(hue: AdjustLevels.clamp(hue, 0, -180...180),
                            saturation: AdjustLevels.clamp(saturation, 0, -100...100),
                            lightness: AdjustLevels.clamp(lightness, 0, -100...100))
    }

    private enum CodingKeys: String, CodingKey { case hue, saturation, lightness }

    /// A missing key is 0; values are read back in range.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = AdjustHueSaturation(hue: try c.decodeIfPresent(Double.self, forKey: .hue) ?? 0,
                                   saturation: try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 0,
                                   lightness: try c.decodeIfPresent(Double.self, forKey: .lightness) ?? 0).clamped()
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
    /// Stops, as both apps' sliders have it.
    public static let exposureRange: ClosedRange<Double> = -5...5

    public init(exposure: Double = 0, levels: AdjustLevels = .neutral, curve: AdjustCurve = .identity,
                hueSaturation: AdjustHueSaturation = .neutral) {
        self.exposure = exposure
        self.levels = levels
        self.curve = curve
        self.hueSaturation = hueSaturation
    }

    /// True when no part changes the picture.
    public var isNeutral: Bool { self == .neutral }

    private enum CodingKeys: String, CodingKey { case exposure, levels, curve, hueSaturation }

    /// Every key optional (a missing part is neutral); every value read back in range.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let exposure = try c.decodeIfPresent(Double.self, forKey: .exposure) ?? 0
        self.init(exposure: AdjustLevels.clamp(exposure, 0, Self.exposureRange),
                  levels: try c.decodeIfPresent(AdjustLevels.self, forKey: .levels) ?? .neutral,
                  curve: try c.decodeIfPresent(AdjustCurve.self, forKey: .curve) ?? .identity,
                  hueSaturation: try c.decodeIfPresent(AdjustHueSaturation.self, forKey: .hueSaturation) ?? .neutral)
    }

    /// Only the parts off neutral, so neutral settings encode to `{}`.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if exposure != 0 { try c.encode(exposure, forKey: .exposure) }
        if levels != .neutral { try c.encode(levels, forKey: .levels) }
        if curve != .identity { try c.encode(curve, forKey: .curve) }
        if hueSaturation != .neutral { try c.encode(hueSaturation, forKey: .hueSaturation) }
    }
}
