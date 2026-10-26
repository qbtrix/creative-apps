// Contracts/DevelopValues.swift: a photo's develop settings (SuiteImaging's
// tone settings, a tone curve, levels), its crop, and the histogram the
// develop panel draws. Levels and curve points are SuiteImaging's types;
// ToneCurve stays Library's own (its ends pinned to 0 and 1, a 0.01 gap) with
// AdjustCurve conversions. Settings are edit instructions, never pixels;
// neutral settings render the photo unchanged. Coded by hand so a catalog
// written before a field existed opens with it neutral, and a neutral new
// field adds no key. The tone is flattened (tone-controls LT-1): each slider
// is its own key in the develop object, as before, never a nested "tone".
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteKernel
import SuiteModel

/// The develop slider is the suite's tone slider. LT-2 drops this name with the
/// develop rows, once LibraryApp's callers say `ToneSlider`.
public typealias DevelopSlider = ToneSlider

extension ToneSlider {
    /// Develop's ten rows, TONE then COLOR: the sliders the panel shows today.
    public static let develop: [ToneSlider] = DevelopGroup.allCases.flatMap(\.sliders)
}

/// A develop section. The raw value is its header.
public enum DevelopGroup: String, CaseIterable, Sendable {
    case tone = "Tone", color = "Color"
    /// The section's rows, in panel order; a section's Reset resets them.
    public var sliders: [ToneSlider] {
        switch self {
        case .tone: [.exposure, .contrast, .highlights, .shadows, .whites, .blacks]
        case .color: [.temperature, .tint, .vibrance, .saturation]
        }
    }
}

/// One point of the tone curve, both coordinates sRGB values in 0...1:
/// SuiteImaging's point, with the catalog's `x` and `y` keys.
public typealias DevelopCurvePoint = AdjustCurvePoint

/// The develop tone curve: a monotone cubic through its points (CoreRaster
/// `curves`), applied to sRGB values. Always valid: built only through `init?`.
public struct ToneCurve: Hashable, Sendable, Codable {
    public static let identity = ToneCurve(valid: [DevelopCurvePoint(x: 0, y: 0), DevelopCurvePoint(x: 1, y: 1)])
    public static let maxPoints = 16
    /// In x.
    public static let minGap = 0.01
    public private(set) var points: [DevelopCurvePoint]

    private init(valid points: [DevelopCurvePoint]) { self.points = points }

    /// Sorted by x; coordinates clamped to 0...1; the first point's x set to 0 and
    /// the last's to 1; a point closer than `minGap` in x to the one before it is
    /// dropped (the end point stays); at most `maxPoints`, the end point among
    /// them. Nil for fewer than 2 finite points.
    public init?(points: [DevelopCurvePoint]) {
        let sorted = points.filter { $0.x.isFinite && $0.y.isFinite }
            .map { DevelopCurvePoint(x: min(max($0.x, 0), 1), y: min(max($0.y, 0), 1)) }
            .sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        guard sorted.count >= 2, let first = sorted.first, let last = sorted.last else { return nil }
        var kept = [first]
        kept[0].x = 0
        for point in sorted.dropFirst().dropLast() {
            guard let previous = kept.last else { continue }
            if point.x - previous.x < Self.minGap || 1 - point.x < Self.minGap { continue }
            kept.append(point)
        }
        kept = Array(kept.prefix(Self.maxPoints - 1))
        kept.append(DevelopCurvePoint(x: 1, y: last.y))
        self.points = kept
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let points = try container.decode([DevelopCurvePoint].self, forKey: .points)
        guard let curve = ToneCurve(points: points) else {
            throw DecodingError.dataCorruptedError(forKey: .points, in: container, debugDescription: "fewer than 2 points")
        }
        self = curve
    }

    /// Every point on y == x.
    public var isIdentity: Bool { points.allSatisfy { $0.x == $0.y } }

    /// The curve at `count` evenly spaced values in 0...1: CoreRaster's `curves`
    /// run on a `count`-pixel grey ramp of those values. The ramp holds the sRGB
    /// values themselves, so `.linear` here maps them by exactly the function
    /// LiveDevelop's `.sRGB` call applies to encoded values, with no transfer
    /// round trip. Empty for `count` < 2 or a curve too steep for a Float.
    public func samples(count: Int = 256) -> [DevelopCurvePoint] {
        guard count >= 2, var ramp = try? PixelBuffer(width: count, height: 1) else { return [] }
        let xs = (0..<count).map { Float($0) / Float(count - 1) }
        for (i, x) in xs.enumerated() { try? ramp.setPixel(x: i, y: 0, RGBA(r: x, g: x, b: x, a: 1)) }
        let corePoints = points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) }
        guard let curved = try? ramp.curves(points: corePoints, encoding: .linear) else { return [] }
        return xs.enumerated().compactMap { i, x in
            (try? curved.pixel(x: i, y: 0)).map { DevelopCurvePoint(x: Double(x), y: Double($0.r)) }
        }
    }
}

/// The develop levels, CoreRaster `levels` on sRGB values: SuiteImaging's
/// levels, which read and write the catalog's keys (`inBlack` ... `outWhite`,
/// 0...1). The rows, `Field` and the setters are LibraryDevelop+Imaging.swift.
public typealias DevelopLevels = AdjustLevels

public struct DevelopSettings: Hashable, Sendable, Codable {
    /// Every slider, as SuiteImaging stores it: a neutral slider is never stored.
    public private(set) var tone = ToneSettings.neutral
    public var exposure: Double { tone.value(.exposure) }
    public var temperature: Double { tone.value(.temperature) }
    public var tint: Double { tone.value(.tint) }
    public var contrast: Double { tone.value(.contrast) }
    public var highlights: Double { tone.value(.highlights) }
    public var shadows: Double { tone.value(.shadows) }
    public var whites: Double { tone.value(.whites) }
    public var blacks: Double { tone.value(.blacks) }
    public var vibrance: Double { tone.value(.vibrance) }
    public var saturation: Double { tone.value(.saturation) }
    /// Never an identity curve other than `ToneCurve.identity`, so equal pictures compare equal.
    public private(set) var curve = ToneCurve.identity
    public private(set) var levels = DevelopLevels.neutral
    /// Nil: the whole photo, upright.
    public private(set) var crop: CropSettings?
    /// How the photo faces before its crop (orientation-crop OC-8); up writes no key.
    public private(set) var orientation: Orientation = .up

    public static let neutral = DevelopSettings()
    public init() {}

    public var isNeutral: Bool { self == .neutral }
    /// True when every slider is neutral, the curve is the identity and levels
    /// are neutral (the crop may still be set).
    public var isAdjustmentNeutral: Bool { tone.isNeutral(nil) && curve.isIdentity && levels == .neutral }

    public func value(_ slider: ToneSlider) -> Double { tone.value(slider) }

    /// A copy with `slider` at `value`, clamped to its range; NaN and infinity give its neutral.
    public func setting(_ slider: ToneSlider, to value: Double) -> DevelopSettings {
        let r = slider.range
        var copy = self
        copy.tone = tone.setting(slider, to: value.isFinite ? min(max(value, r.lowerBound), r.upperBound) : slider.neutral)
        return copy
    }

    public func setting(curve: ToneCurve) -> DevelopSettings {
        var copy = self
        copy.curve = curve.isIdentity ? .identity : curve
        return copy
    }

    public func setting(levels: DevelopLevels) -> DevelopSettings {
        var copy = self
        copy.levels = levels
        return copy
    }

    public func setting(crop: CropSettings?) -> DevelopSettings {
        var copy = self
        copy.crop = crop
        return copy
    }

    public func setting(orientation: Orientation) -> DevelopSettings {
        var copy = self
        copy.orientation = orientation
        return copy
    }

    /// Every adjustment of `other` with this crop and orientation: Paste Settings never pastes either.
    public func pastingAdjustments(from other: DevelopSettings) -> DevelopSettings {
        var copy = other
        copy.crop = crop
        copy.orientation = orientation
        return copy
    }

    /// FNV-1a 64 over the settings' sorted-key JSON: every field, so any edit
    /// changes it. Deterministic across processes (never `hashValue`).
    public var fingerprint: UInt64 {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let bytes = (try? encoder.encode(self)) ?? Data()
        return bytes.reduce(0xcbf2_9ce4_8422_2325 as UInt64) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3 }
    }

    /// A slider's raw value, or crop, curve, levels or orientation: the develop object's flat keys.
    private struct Key: CodingKey {
        let stringValue: String
        init(_ name: String) { stringValue = name }
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
        static let crop = Key("crop"), curve = Key("curve"), levels = Key("levels"), orientation = Key("orientation")
        static func slider(_ s: ToneSlider) -> Key { Key(s.rawValue) }
    }

    /// The six sliders the first catalog wrote: always written, required on read.
    private static let required: Set<ToneSlider> = [.exposure, .contrast, .highlights, .shadows, .temperature, .tint]

    /// The six original sliders are required, as the synthesized coding had them;
    /// every newer key decodes as its default when missing, so an older catalog opens.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        for slider in ToneSlider.allCases {
            let key = Key.slider(slider)
            let value = Self.required.contains(slider)
                ? try c.decode(Double.self, forKey: key) : try c.decodeIfPresent(Double.self, forKey: key)
            if let value { tone = tone.setting(slider, to: value) }
        }
        crop = try c.decodeIfPresent(CropSettings.self, forKey: .crop)
        let decodedCurve = try c.decodeIfPresent(ToneCurve.self, forKey: .curve) ?? .identity
        curve = decodedCurve.isIdentity ? .identity : decodedCurve
        levels = try c.decodeIfPresent(DevelopLevels.self, forKey: .levels) ?? .neutral
        orientation = try c.decodeIfPresent(Orientation.self, forKey: .orientation) ?? .up
    }

    /// The six original sliders always and the crop when set (so persist's golden
    /// stays byte-equal); every other slider and field only when off its default.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        for slider in ToneSlider.allCases where Self.required.contains(slider) || tone.value(slider) != slider.neutral {
            try c.encode(tone.value(slider), forKey: .slider(slider))
        }
        try c.encodeIfPresent(crop, forKey: .crop)
        if !curve.isIdentity { try c.encode(curve, forKey: .curve) }
        if levels != .neutral { try c.encode(levels, forKey: .levels) }
        if orientation != .up { try c.encode(orientation, forKey: .orientation) }
    }
}

/// A rectangle in 0...1 of an image's width and height.
public struct UnitRect: Hashable, Sendable, Codable {
    public var x: Double, y: Double, width: Double, height: Double
    public static let full = UnitRect(x: 0, y: 0, width: 1, height: 1)
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// The crop's aspect: the kernel's (orientation-crop OC-8), whose raw values are the stored keys.
public typealias CropAspect = SuiteKernel.CropAspect

extension SuiteKernel.CropAspect {
    public static let square = CropAspect.ratio(width: 1, height: 1)
    public static let fourFive = CropAspect.ratio(width: 4, height: 5)
    public static let threeTwo = CropAspect.ratio(width: 3, height: 2)
    public static let sixteenNine = CropAspect.ratio(width: 16, height: 9)
    /// Library's chips, in order.
    public static let allCases: [CropAspect] = [.original, .free, .square, .fourFive, .threeTwo, .sixteenNine]

    /// Width over height for a photo of `size` (a 3:2 on a portrait photo is 2:3); nil for Free.
    public func ratio(for size: PixelSize) -> Double? {
        ratio(for: (Double(size.width), Double(size.height)), orientation: nil)
    }
}

public struct CropSettings: Hashable, Sendable, Codable {
    public static let angleRange: ClosedRange<Double> = -45...45
    /// Degrees clockwise, in `angleRange`.
    public var angle: Double
    /// In 0...1 of the straightened photo's largest upright crop
    /// (CoreRaster `PixelBuffer.straightenCrop`), so no transparent corner shows.
    public var rect: UnitRect
    public var aspect: CropAspect
    public init(angle: Double, rect: UnitRect, aspect: CropAspect) {
        self.angle = angle; self.rect = rect; self.aspect = aspect
    }
}

/// A crop frame handle.
public enum CropHandle: Sendable, Hashable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, inside
}

/// The develop panel's histogram: 256 bins per channel over sRGB-encoded
/// values (what a display shows), plus clipping counts.
public struct HistogramBins: Hashable, Sendable {
    public static let binCount = 256
    public let red: [Int], green: [Int], blue: [Int]
    public let shadowClipped: Int, highlightClipped: Int
    public static let empty = HistogramBins(
        red: Array(repeating: 0, count: binCount), green: Array(repeating: 0, count: binCount),
        blue: Array(repeating: 0, count: binCount), shadowClipped: 0, highlightClipped: 0)
    public init(red: [Int], green: [Int], blue: [Int], shadowClipped: Int, highlightClipped: Int) {
        self.red = red; self.green = green; self.blue = blue
        self.shadowClipped = shadowClipped; self.highlightClipped = highlightClipped
    }
    /// The suite's display shape: the three channels summed per bin, the tallest at 1, with the clip flags.
    public var tone: ToneHistogram {
        ToneHistogram(channels: [red, green, blue], shadowClipped: shadowClipped, highlightClipped: highlightClipped)
    }
}

/// A preview is drawn from the thumbnail-size decode while a drag is under
/// way; full is the screen-size render it settles to.
public enum RenderQuality: String, Sendable, Hashable { case preview, full }

/// The loupe's picture and its histogram. `tone`, the histogram's display
/// shape, is made where the render is (LiveLoupeImaging's actor, off the main
/// thread), once per render, so the window only reads it.
public struct RenderedPhoto: Hashable, Sendable {
    public var image: DisplayImage
    public var histogram: HistogramBins { didSet { tone = histogram.tone } }
    public private(set) var tone: ToneHistogram
    public var quality: RenderQuality
    public init(image: DisplayImage, histogram: HistogramBins, quality: RenderQuality) {
        self.image = image; self.histogram = histogram; self.quality = quality
        tone = histogram.tone
    }
}
