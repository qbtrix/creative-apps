// PhotoItem.swift: one photo in the Library catalog, plus the sort orders and
// the browse mode. Linux-safe value types. The color stands in for pixels
// until import reads real files (L2); it is sRGB from CoreColor.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor

/// A color label; the raw value names it for people who can't tell the colors apart.
public enum PhotoLabel: String, CaseIterable, Sendable, Hashable {
    case red = "Red", yellow = "Yellow", green = "Green", blue = "Blue", purple = "Purple"
}

public struct PhotoItem: Identifiable, Sendable, Hashable {
    public var id: String { name }
    /// The file name without extension, e.g. "IMG_0001".
    public let name: String
    public let captureDate: Date
    public let color: Color3  // flat sRGB, each component in 0...1
    public let rating: Int  // stars, 0...5
    public let isFlagged: Bool  // a pick: Favorites shows these
    public let label: PhotoLabel?

    public init(
        name: String, captureDate: Date, color: Color3, rating: Int = 0, isFlagged: Bool = false,
        label: PhotoLabel? = nil
    ) {
        self.name = name
        self.captureDate = captureDate
        self.color = color.clampedToUnit()
        self.rating = min(max(rating, 0), 5)
        self.isFlagged = isFlagged
        self.label = label
    }

    /// The color as one opaque RGBA8 pixel, the thumbnail the grid draws.
    public var pixel: [UInt8] {
        [color.c0, color.c1, color.c2].map { UInt8(($0 * 255).rounded()) } + [255]
    }
}

/// View > Sort By. Ties fall back to the name, so every order is stable.
/// The raw value is the menu title.
public enum LibrarySort: String, CaseIterable, Sendable, Hashable {
    case captureDate = "Capture Date", name = "Name", rating = "Rating"  // oldest, A to Z, most stars first

    /// True when `a` comes before `b` in this order.
    func orders(_ a: PhotoItem, before b: PhotoItem) -> Bool {
        switch self {
        case .captureDate where a.captureDate != b.captureDate: a.captureDate < b.captureDate
        case .rating where a.rating != b.rating: a.rating > b.rating
        default: a.name < b.name
        }
    }
}

/// What the content area shows: the grid, or one photo in the loupe.
public enum LibraryMode: Sendable, Hashable { case grid, loupe }
