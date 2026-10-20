// SampleRules.swift (eyedropper EY-1 stubs, EY-5 bodies): the one N × N mean every sampler uses, over a reader
// closure, so a pixel app's composite, a vector app's render and the gallery's fake canvas read colours the same
// way.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The square an eyedropper reads: the pixel under the point, or the 3 × 3 or 5 × 5 square centred on it.
public enum SampleSize: Int, Hashable, Sendable, CaseIterable, Codable {
    case point = 1, threeByThree = 3, fiveByFive = 5

    /// The size chip's title.
    public var title: String {
        switch self {
        case .point: "Point"
        case .threeByThree: "3 × 3"
        case .fiveByFive: "5 × 5"
        }
    }
}

/// One pixel as a reader hands it to the sampler: 8-bit sRGB, straight alpha.
public struct SampleRGBA: Hashable, Sendable {
    public var r, g, b, a: UInt8
    public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) { (self.r, self.g, self.b, self.a) = (r, g, b, a) }
}

public enum SampleRules {
    /// The mean of the size × size square centred on (x, y) over the pixels `read` returns (nil outside the
    /// image) that aren't fully transparent, each weighted by its alpha; nil when there are none.
    /// The colour channels are the alpha-weighted means; alpha is the mean alpha of the pixels counted.
    public static func mean(x: Int, y: Int, size: SampleSize, read: (Int, Int) -> SampleRGBA?) -> FillColor? {
        let half = size.rawValue / 2, offsets = -half...half
        var (r, g, b, sumA, count) = (0.0, 0.0, 0.0, 0.0, 0)
        for dy in offsets {
            for dx in offsets {
                guard let pixel = read(x + dx, y + dy), pixel.a > 0 else { continue }
                let a = Double(pixel.a)
                r += Double(pixel.r) * a
                g += Double(pixel.g) * a
                b += Double(pixel.b) * a
                sumA += a
                count += 1
            }
        }
        guard sumA > 0 else { return nil }
        return FillColor(r: r / sumA / 255, g: g / sumA / 255, b: b / sumA / 255, a: sumA / Double(count) / 255)
    }

    /// `color` as "#RRGGBB", each channel rounded.
    public static func hex(_ color: FillColor) -> String {
        "#" + [color.r, color.g, color.b].map { channel in
            let digits = String(byte(channel), radix: 16, uppercase: true)
            return digits.count < 2 ? "0" + digits : digits
        }.joined()
    }

    /// A 0...1 channel as 0...255, rounded; out of range clamps, NaN reads 0.
    public static func byte(_ channel: Double) -> Int {
        channel.isNaN ? 0 : Int((min(max(channel, 0), 1) * 255).rounded())
    }
}
