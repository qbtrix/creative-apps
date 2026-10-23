// Contracts/DevelopValues.swift: a photo's develop settings (ten sliders, a
// tone curve, levels), its crop, and the histogram the develop panel draws.
// Settings are edit instructions, never pixels; neutral settings render the
// photo unchanged. Coded by hand so a catalog written before a field existed
// opens with it neutral, and a neutral new field adds no key.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteModel

/// One develop slider. The raw value is the row's label.
public enum DevelopSlider: String, CaseIterable, Sendable, Codable {
    // The panel's order: TONE, then COLOR.
    case exposure = "Exposure", contrast = "Contrast", highlights = "Highlights", shadows = "Shadows"
    case whites = "Whites", blacks = "Blacks"
    case temperature = "Temperature", tint = "Tint"
    case vibrance = "Vibrance", saturation = "Saturation"

    /// The inspector section the row sits in; a section's Reset resets its group.
    public var group: DevelopGroup {
        switch self {
        case .exposure, .contrast, .highlights, .shadows, .whites, .blacks: .tone
        case .temperature, .tint, .vibrance, .saturation: .color
        }
    }

    /// Exposure in stops, -5...5; the rest -100...100 (CoreRaster's slider range).
    public var range: ClosedRange<Double> { self == .exposure ? -5...5 : -100...100 }
    /// One arrow-key step; Shift is ten, Option a tenth (docs/design.md, Scrub fields).
    public var step: Double { self == .exposure ? 0.01 : 1 }
}

/// A develop section. The raw value is its header.
public enum DevelopGroup: String, CaseIterable, Sendable {
    case tone = "Tone", color = "Color"
    public var sliders: [DevelopSlider] { DevelopSlider.allCases.filter { $0.group == self } }
}

/// One point of the tone curve, both coordinates sRGB values in 0...1.
public struct DevelopCurvePoint: Hashable, Sendable, Codable {
    public var x: Double, y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

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

/// The develop levels, CoreRaster `levels` on sRGB values.
public struct DevelopLevels: Hashable, Sendable, Codable {
    /// The raw value is the row's label.
    public enum Field: String, CaseIterable, Sendable {
        case inBlack = "Black Point", gamma = "Midtones", inWhite = "White Point"
        case outBlack = "Output Black", outWhite = "Output White"
    }
    public static let neutral = DevelopLevels()
    public static let gammaRange: ClosedRange<Double> = 0.1...9.99
    /// The least gap between the black and white points: one byte level.
    public static let pointGap = 1.0 / 255
    /// sRGB values in 0...1 (the rows show them as 0...255); gamma over 1 brightens.
    public private(set) var inBlack = 0.0, inWhite = 1.0, gamma = 1.0, outBlack = 0.0, outWhite = 1.0
    public init() {}

    /// A decoded file goes through `setting`, so damaged levels can't reach the renderer.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var levels = DevelopLevels.neutral
        for (field, key) in [(Field.outBlack, CodingKeys.outBlack), (.outWhite, .outWhite), (.gamma, .gamma),
                             (.inWhite, .inWhite), (.inBlack, .inBlack)] {
            if let value = try container.decodeIfPresent(Double.self, forKey: key) {
                levels = levels.setting(field, to: value)
            }
        }
        self = levels
    }

    public func value(_ field: Field) -> Double {
        switch field {
        case .inBlack: inBlack
        case .gamma: gamma
        case .inWhite: inWhite
        case .outBlack: outBlack
        case .outWhite: outWhite
        }
    }

    /// Clamped to the field's range; NaN or infinity gives the neutral value. The
    /// black and white points stay at least `pointGap` apart: the one being moved stops there.
    public func setting(_ field: Field, to value: Double) -> DevelopLevels {
        let wanted = value.isFinite ? value : Self.neutral.value(field)
        var copy = self
        switch field {
        case .inBlack: copy.inBlack = min(max(wanted, 0), inWhite - Self.pointGap)
        case .gamma: copy.gamma = min(max(wanted, Self.gammaRange.lowerBound), Self.gammaRange.upperBound)
        case .inWhite: copy.inWhite = min(max(wanted, inBlack + Self.pointGap), 1)
        case .outBlack: copy.outBlack = min(max(wanted, 0), 1)
        case .outWhite: copy.outWhite = min(max(wanted, 0), 1)
        }
        return copy
    }
}

public struct DevelopSettings: Hashable, Sendable, Codable {
    public private(set) var exposure: Double = 0
    public private(set) var temperature: Double = 0
    public private(set) var tint: Double = 0
    public private(set) var contrast: Double = 0
    public private(set) var highlights: Double = 0
    public private(set) var shadows: Double = 0
    public private(set) var whites = 0.0, blacks = 0.0, vibrance = 0.0, saturation = 0.0
    /// Never an identity curve other than `ToneCurve.identity`, so equal pictures compare equal.
    public private(set) var curve = ToneCurve.identity
    public private(set) var levels = DevelopLevels.neutral
    /// Nil: the whole photo, upright.
    public private(set) var crop: CropSettings?

    public static let neutral = DevelopSettings()
    public init() {}

    public var isNeutral: Bool { self == .neutral }
    /// True when no slider is off zero, the curve is the identity and levels are
    /// neutral (the crop may still be set).
    public var isAdjustmentNeutral: Bool {
        DevelopSlider.allCases.allSatisfy { value($0) == 0 } && curve.isIdentity && levels == .neutral
    }

    public func value(_ slider: DevelopSlider) -> Double {
        switch slider {
        case .exposure: exposure
        case .temperature: temperature
        case .tint: tint
        case .contrast: contrast
        case .highlights: highlights
        case .shadows: shadows
        case .whites: whites
        case .blacks: blacks
        case .vibrance: vibrance
        case .saturation: saturation
        }
    }

    /// A copy with `slider` at `value`, clamped to its range; NaN and infinity give 0.
    public func setting(_ slider: DevelopSlider, to value: Double) -> DevelopSettings {
        let clamped = value.isFinite ? min(max(value, slider.range.lowerBound), slider.range.upperBound) : 0
        var copy = self
        switch slider {
        case .exposure: copy.exposure = clamped
        case .temperature: copy.temperature = clamped
        case .tint: copy.tint = clamped
        case .contrast: copy.contrast = clamped
        case .highlights: copy.highlights = clamped
        case .shadows: copy.shadows = clamped
        case .whites: copy.whites = clamped
        case .blacks: copy.blacks = clamped
        case .vibrance: copy.vibrance = clamped
        case .saturation: copy.saturation = clamped
        }
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

    /// Every adjustment of `other` with this crop: Paste Settings never pastes a crop.
    public func pastingAdjustments(from other: DevelopSettings) -> DevelopSettings {
        var copy = other
        copy.crop = crop
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

    private enum CodingKeys: String, CodingKey {
        case exposure, contrast, highlights, shadows, temperature, tint, crop
        case whites, blacks, vibrance, saturation, curve, levels
    }

    /// The six original sliders are required, as the synthesized coding had them;
    /// every newer key decodes as its default when missing, so an older catalog opens.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exposure = try c.decode(Double.self, forKey: .exposure)
        contrast = try c.decode(Double.self, forKey: .contrast)
        highlights = try c.decode(Double.self, forKey: .highlights)
        shadows = try c.decode(Double.self, forKey: .shadows)
        temperature = try c.decode(Double.self, forKey: .temperature)
        tint = try c.decode(Double.self, forKey: .tint)
        crop = try c.decodeIfPresent(CropSettings.self, forKey: .crop)
        whites = try c.decodeIfPresent(Double.self, forKey: .whites) ?? 0
        blacks = try c.decodeIfPresent(Double.self, forKey: .blacks) ?? 0
        vibrance = try c.decodeIfPresent(Double.self, forKey: .vibrance) ?? 0
        saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 0
        let decodedCurve = try c.decodeIfPresent(ToneCurve.self, forKey: .curve) ?? .identity
        curve = decodedCurve.isIdentity ? .identity : decodedCurve
        levels = try c.decodeIfPresent(DevelopLevels.self, forKey: .levels) ?? .neutral
    }

    /// The six original sliders always and the crop when set (so persist's golden
    /// stays byte-equal); every newer field only when off its default.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(exposure, forKey: .exposure)
        try c.encode(contrast, forKey: .contrast)
        try c.encode(highlights, forKey: .highlights)
        try c.encode(shadows, forKey: .shadows)
        try c.encode(temperature, forKey: .temperature)
        try c.encode(tint, forKey: .tint)
        try c.encodeIfPresent(crop, forKey: .crop)
        if whites != 0 { try c.encode(whites, forKey: .whites) }
        if blacks != 0 { try c.encode(blacks, forKey: .blacks) }
        if vibrance != 0 { try c.encode(vibrance, forKey: .vibrance) }
        if saturation != 0 { try c.encode(saturation, forKey: .saturation) }
        if !curve.isIdentity { try c.encode(curve, forKey: .curve) }
        if levels != .neutral { try c.encode(levels, forKey: .levels) }
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

/// The crop's aspect. The raw value is the chip's title.
public enum CropAspect: String, CaseIterable, Sendable, Codable {
    case original = "Original", free = "Free", square = "1:1"
    case fourFive = "4:5", threeTwo = "3:2", sixteenNine = "16:9"

    /// Width over height for a photo of `size` (a 3:2 on a portrait photo is 2:3); nil for Free.
    public func ratio(for size: PixelSize) -> Double? {
        let portrait = size.height > size.width
        let base: Double? = switch self {
        case .free: nil
        case .original: size.height > 0 ? Double(size.width) / Double(size.height) : nil
        case .square: 1
        case .fourFive: 4.0 / 5.0
        case .threeTwo: 3.0 / 2.0
        case .sixteenNine: 16.0 / 9.0
        }
        guard let base, self != .original, self != .square else { return base }
        return portrait == (base > 1) ? 1 / base : base
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
