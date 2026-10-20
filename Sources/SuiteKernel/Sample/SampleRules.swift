// SampleRules.swift (eyedropper EY-1 stubs, EY-5 bodies): the one N × N mean every sampler uses, over a reader
// closure, so a pixel app's composite, a vector app's render and the gallery's fake canvas read colours the same
// way. The stubs answer nil and "#000000" until EY-5 fills them in.
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
    /// What `color.sample`'s run throws until EY-6 builds its body.
    public static let notBuilt = CatalogError.notBuilt(id: "color.sample", feature: "eyedropper")

    /// The mean of the size × size square centred on (x, y) over the pixels `read` returns (nil outside the
    /// image) that aren't fully transparent, each weighted by its alpha; nil when there are none.
    /// EY-1 stub: nil.
    public static func mean(x: Int, y: Int, size: SampleSize, read: (Int, Int) -> SampleRGBA?) -> FillColor? {
        nil
    }

    /// `color` as "#RRGGBB", each channel rounded. EY-1 stub: "#000000".
    public static func hex(_ color: FillColor) -> String { "#000000" }
}
