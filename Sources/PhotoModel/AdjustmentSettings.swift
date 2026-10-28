// AdjustmentSettings.swift: the values behind Photo's adjustments inspector:
// exposure, levels, curves, blur and hue/saturation, each with an enable
// switch. Exposure and levels are Float like CoreRaster's parameters; sigma is
// Double. Every change arrives as one AdjustmentEdit: values clamp to their
// range, NaN is ignored, and a black point at or above the white point (or
// the reverse) is refused, keeping the old value. A Gamma field commit of the
// value it shows changes nothing. Black and white snap to levelsStep, and the
// inspector shows them at levelsDecimals, so two distinct points never read
// the same and a shown value types back in as itself. Curves holds 2 to 16
// points (curvePointCount), x strictly increasing in 0...1 and y clamped to
// 0...1; any other list, or a non-finite value, is refused whole. The default
// end points (0, 0) and (1, 1) are identity. Levels' points and the curve's
// coordinates are display (sRGB-encoded) values, so 0.5 is the grey a screen
// shows halfway between black and white. PhotoRender applies the enabled
// sections to the canvas (exposure, levels, curves, hue/saturation, then
// blur). Settings are Hashable, so an adjustment layer can hold them, and
// Codable, so a document can store them. Exposure, levels, the curve and
// hue/saturation live in SuiteImaging's AdjustSettings (`imaging`); Photo's
// Float values, the stored form and the render's steps are read out of it in
// PhotoAdjust+Imaging.swift. `tone` is the suite's ToneSettings (white
// balance, tone, presence, sharpen; tone-controls PT-1), set whole by one
// `.tone` edit; it has no AdjustmentKind, so it has no switch and no section
// of its own, and PT-3 renders it. `kinds` holds Black & White and Invert (AJ-8);
// their switch is whether the list holds them, never `enabled`. Linux-safe.
import CoreRaster
import SuiteImaging

/// One adjustment section in the inspector.
public enum AdjustmentKind: String, CaseIterable, Sendable, Codable {
    case exposure, levels, curves, blur, hueSaturation, blackAndWhite, invert

    /// The sections with values and a switch of their own, the ones `enabled` holds.
    public static let sections: [AdjustmentKind] = [.exposure, .levels, .curves, .blur, .hueSaturation]
}

extension ImagingKind {
    var adjustment: AdjustmentKind {
        switch self {
        case .blackAndWhite: .blackAndWhite
        case .invert: .invert
        }
    }
}

/// One change the inspector can ask for.
public enum AdjustmentEdit: Sendable, Equatable {
    case exposure(Float)
    case blackPoint(Float)
    case whitePoint(Float)
    case gamma(Float)
    /// The Gamma field's commit: a value equal to gamma as the field shows it
    /// (gammaDecimals places) is the field re-sending its own text, so gamma
    /// keeps its full precision and nothing is recorded.
    case gammaField(Double)
    /// The tone curve's whole point list, left to right.
    case curvePoints([CurvePoint])
    case blurSigma(Double)
    case hue(Double)
    case saturation(Double)
    case lightness(Double)
    case setEnabled(AdjustmentKind, Bool)
    /// Puts a section's values back to their defaults; its switch stays.
    case reset(AdjustmentKind)
    /// The whole tone section, as the tone commands set it: one edit, one step.
    case tone(ToneSettings)
}

public struct AdjustmentSettings: Sendable, Hashable {
    public static let exposureRange: ClosedRange<Float> = -5...5
    public static let levelsRange: ClosedRange<Float> = 0...1
    /// Black and white snap to thousandths: fine next to 8-bit's 1/255.
    public static let levelsStep: Double = 0.001
    /// The places that show every levelsStep value exactly.
    public static let levelsDecimals = 3
    public static let gammaRange: ClosedRange<Float> = 0.1...10
    /// The places the Gamma field shows.
    public static let gammaDecimals = 2
    /// How many points a tone curve takes.
    public static let curvePointCount = 2...16
    /// Up to 20 px: the canvas renders a blur tile by tile with a 3-sigma
    /// margin, and past 20 that margin costs more than the tile.
    public static let sigmaRange: ClosedRange<Double> = 0...20
    public static let hueRange: ClosedRange<Double> = -180...180
    /// Saturation and lightness.
    public static let percentRange: ClosedRange<Double> = -100...100

    /// Exposure, levels, the tone curve and hue/saturation, in the suite's
    /// shared value; `exposure`, `blackPoint` and the rest read it.
    public private(set) var imaging = AdjustSettings.neutral
    /// Gaussian blur radius in pixels.
    public private(set) var blurSigma: Double = 0
    public private(set) var enabled: Set<AdjustmentKind> = Set(AdjustmentKind.sections)
    /// White balance, tone, presence and sharpen; stored under "tone", left
    /// out when neutral.
    public private(set) var tone: ToneSettings = .neutral
    /// Black & White and Invert, in the order they run after hue/saturation.
    public private(set) var kinds: [ImagingKind] = []

    public init() {}

    /// The stored form read back (PhotoAdjust+Imaging.swift), unchecked like
    /// the stored values themselves.
    init(imaging: AdjustSettings, blurSigma: Double, enabled: Set<AdjustmentKind>, tone: ToneSettings = .neutral,
         kinds: [ImagingKind] = []) {
        (self.imaging, self.blurSigma, self.enabled, self.tone, self.kinds) = (imaging, blurSigma, enabled, tone, kinds)
    }

    /// A section's switch; Black & White's and Invert's is whether `kinds` holds them.
    public func isEnabled(_ kind: AdjustmentKind) -> Bool {
        AdjustmentKind.sections.contains(kind) ? enabled.contains(kind) : kinds.contains { $0.adjustment == kind }
    }

    /// Replaces the kinds (AdjustTarget's `setKinds`).
    mutating func setKinds(_ kinds: [ImagingKind]) { self.kinds = kinds }

    /// Imaging, tone and kinds from `look`; blur and the switches stay.
    mutating func apply(_ look: LookPreset) {
        (imaging, tone, kinds) = (look.adjust, look.tone, look.kinds)
    }

    /// Whether a section's values leave the image as it is.
    public func isIdentity(_ kind: AdjustmentKind) -> Bool {
        var defaults = self
        defaults.reset(kind)
        return defaults == self
    }

    /// True when no enabled section, and no tone slider, changes the image.
    public var isIdentity: Bool {
        tone.isNeutral(nil) && AdjustmentKind.allCases.allSatisfy { !isEnabled($0) || isIdentity($0) }
    }

    public mutating func apply(_ edit: AdjustmentEdit) {
        switch edit {
        case .exposure(let value):
            imaging.exposure = Double(Self.clamp(value, to: Self.exposureRange) ?? exposure)
        case .blackPoint(let value):
            if let value = Self.levelsValue(value), value < whitePoint { imaging.levels.inputBlack = Double(value) }
        case .whitePoint(let value):
            if let value = Self.levelsValue(value), value > blackPoint { imaging.levels.inputWhite = Double(value) }
        case .gamma(let value):
            imaging.levels.gamma = Double(Self.clamp(value, to: Self.gammaRange) ?? gamma)
        case .gammaField(let value):
            if !Self.showsAs(value, gamma) { apply(.gamma(Float(value))) }
        case .curvePoints(let points):
            if let points = Self.curve(points) { imaging.curve = Self.imagingCurve(points) }
        case .blurSigma(let value):
            blurSigma = Self.clamp(value, to: Self.sigmaRange) ?? blurSigma
        case .hue(let value):
            imaging.hueSaturation.hue = Self.clamp(value, to: Self.hueRange) ?? hue
        case .saturation(let value):
            imaging.hueSaturation.saturation = Self.clamp(value, to: Self.percentRange) ?? saturation
        case .lightness(let value):
            imaging.hueSaturation.lightness = Self.clamp(value, to: Self.percentRange) ?? lightness
        case .setEnabled(let kind, let isOn) where !AdjustmentKind.sections.contains(kind):
            if !isOn {
                kinds.removeAll { $0.adjustment == kind }
            } else if !isEnabled(kind) {
                kinds.append(kind == .invert ? .invert : .blackAndWhite(.neutral))
            }
        case .setEnabled(let kind, let isOn):
            if isOn { enabled.insert(kind) } else { enabled.remove(kind) }
        case .reset(let kind):
            reset(kind)
        case .tone(let settings):
            tone = settings
        }
    }

    private mutating func reset(_ kind: AdjustmentKind) {
        let defaults = AdjustmentSettings()
        switch kind {
        case .exposure:
            imaging.exposure = defaults.imaging.exposure
        case .levels:
            imaging.levels = defaults.imaging.levels
        case .curves:
            imaging.curve = defaults.imaging.curve
        case .blur:
            blurSigma = defaults.blurSigma
        case .hueSaturation:
            imaging.hueSaturation = defaults.imaging.hueSaturation
        case .blackAndWhite, .invert:
            kinds.removeAll { $0.adjustment == kind }
        }
    }

    /// `value` clamped to levelsRange and snapped to levelsStep, or nil for NaN.
    /// Snapping after the clamp keeps the result inside the range.
    private static func levelsValue(_ value: Float) -> Float? {
        guard let clamped = clamp(value, to: levelsRange) else { return nil }
        return Float((Double(clamped) / levelsStep).rounded() * levelsStep)
    }

    /// Whether `value` is `gamma` rounded to gammaDecimals, halves away from
    /// zero as the field formats it. NaN never is.
    private static func showsAs(_ value: Double, _ gamma: Float) -> Bool {
        var scale = 1.0
        for _ in 0..<gammaDecimals { scale *= 10 }
        return abs(value - (Double(gamma) * scale).rounded() / scale) < 1e-9
    }

    /// `points` with each y clamped to 0...1, or nil for a list Curves refuses:
    /// a count outside curvePointCount, a non-finite value, an x outside 0...1
    /// or an x not above the one before.
    private static func curve(_ points: [CurvePoint]) -> [CurvePoint]? {
        guard curvePointCount.contains(points.count),
            points.allSatisfy({ (0...1).contains($0.x) && $0.y.isFinite }),
            zip(points, points.dropFirst()).allSatisfy({ $0.x < $1.x })
        else { return nil }
        return points.map { CurvePoint(x: $0.x, y: min(max($0.y, 0), 1)) }
    }

    /// `value` inside `range`, or nil for NaN.
    private static func clamp<Value: BinaryFloatingPoint>(_ value: Value, to range: ClosedRange<Value>) -> Value? {
        value.isNaN ? nil : min(max(value, range.lowerBound), range.upperBound)
    }
}

/// CoreRaster's curve point as `{"x": …, "y": …}`, for a stored document.
extension CurvePoint: @retroactive Codable {
    private enum CodingKeys: String, CodingKey { case x, y }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try container.decode(Float.self, forKey: .x), y: try container.decode(Float.self, forKey: .y))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}
