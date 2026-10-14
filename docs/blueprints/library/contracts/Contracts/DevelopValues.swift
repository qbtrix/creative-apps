// Contracts/DevelopValues.swift: a photo's develop settings, its crop, and
// the histogram the develop panel draws. Settings are edit instructions,
// never pixels; neutral settings render the photo unchanged.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One develop slider. The raw value is the row's label.
public enum DevelopSlider: String, CaseIterable, Sendable, Codable {
    // The panel's order: TONE, then COLOR.
    case exposure = "Exposure", contrast = "Contrast", highlights = "Highlights", shadows = "Shadows"
    case temperature = "Temperature", tint = "Tint"

    /// The inspector section the row sits in; a section's Reset resets its group.
    public var group: DevelopGroup {
        switch self {
        case .exposure, .contrast, .highlights, .shadows: .tone
        case .temperature, .tint: .color
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

public struct DevelopSettings: Hashable, Sendable, Codable {
    public private(set) var exposure: Double = 0
    public private(set) var temperature: Double = 0
    public private(set) var tint: Double = 0
    public private(set) var contrast: Double = 0
    public private(set) var highlights: Double = 0
    public private(set) var shadows: Double = 0
    /// Nil: the whole photo, upright.
    public private(set) var crop: CropSettings?

    public static let neutral = DevelopSettings()
    public init() {}

    public var isNeutral: Bool { self == .neutral }
    /// True when no slider is off zero (the crop may still be set).
    public var isAdjustmentNeutral: Bool { DevelopSlider.allCases.allSatisfy { value($0) == 0 } }

    public func value(_ slider: DevelopSlider) -> Double {
        switch slider {
        case .exposure: exposure
        case .temperature: temperature
        case .tint: tint
        case .contrast: contrast
        case .highlights: highlights
        case .shadows: shadows
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
        }
        return copy
    }

    public func setting(crop: CropSettings?) -> DevelopSettings {
        var copy = self
        copy.crop = crop
        return copy
    }

    /// All six sliders of `other` with this crop: Paste Settings never pastes a crop.
    public func pastingAdjustments(from other: DevelopSettings) -> DevelopSettings {
        var copy = other
        copy.crop = crop
        return copy
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
    /// Each channel scaled to 0...1 by the tallest bin of all three; all 0 (never NaN) when empty.
    public var heights: (red: [Double], green: [Double], blue: [Double]) {
        let tallest = Double(max(red.max() ?? 0, green.max() ?? 0, blue.max() ?? 0))
        let scale: ([Int]) -> [Double] = { bins in bins.map { tallest > 0 ? Double($0) / tallest : 0 } }
        return (scale(red), scale(green), scale(blue))
    }
}

/// A preview is drawn from the thumbnail-size decode while a drag is under
/// way; full is the screen-size render it settles to.
public enum RenderQuality: String, Sendable, Hashable { case preview, full }

/// The loupe's picture and its histogram.
public struct RenderedPhoto: Hashable, Sendable {
    public var image: DisplayImage
    public var histogram: HistogramBins
    public var quality: RenderQuality
    public init(image: DisplayImage, histogram: HistogramBins, quality: RenderQuality) {
        self.image = image; self.histogram = histogram; self.quality = quality
    }
}
