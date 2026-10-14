// PhotoItem.swift: one photo in the Library catalog, plus the sort orders and
// the browse mode. Linux-safe value types. The color stands in for pixels
// until import reads real files (L2); it is sRGB from CoreColor. Rating, flag
// and label change only through LibraryCatalog's metadata edits
// (MetadataEditing.swift), which keep the rating in 0...5.
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
    /// Unique within a catalog; `LibraryCatalog.load(_:)` renames clashes.
    public let id: String
    /// The file name without extension, e.g. "IMG_0001".
    public let name: String
    public let captureDate: Date
    public let color: Color3  // flat sRGB, each component in 0...1
    public internal(set) var rating: Int  // stars, 0...5
    public internal(set) var flag: PhotoFlag
    public internal(set) var label: PhotoLabel?
    /// The file's absolute path; nil for a generated sample. Equal to `id` for an imported photo.
    public let path: String?
    /// After the Exif orientation; samples use `LibraryCatalog.loupeArtboard`.
    public let pixelSize: PixelSize
    /// Edit instructions; neutral until the person develops the photo.
    public internal(set) var develop: DevelopSettings
    /// Whether the file can be read now; set when a decode fails or succeeds.
    public internal(set) var availability: PhotoAvailability

    /// `id` defaults to the name; two photos may share a name but not an id.
    /// `isFlagged` makes it a pick unless `flag` says otherwise.
    public init(
        id: String? = nil, name: String, captureDate: Date, color: Color3, rating: Int = 0,
        isFlagged: Bool = false, label: PhotoLabel? = nil, flag: PhotoFlag? = nil, path: String? = nil,
        pixelSize: PixelSize = PixelSize(width: 4032, height: 3024), develop: DevelopSettings = .neutral,
        availability: PhotoAvailability = .available
    ) {
        self.id = id ?? name
        self.name = name
        self.captureDate = captureDate
        self.color = color.clampedToUnit()
        self.rating = min(max(rating, 0), 5)
        self.flag = flag ?? (isFlagged ? .pick : .none)
        self.label = label
        self.path = path
        self.pixelSize = pixelSize
        self.develop = develop
        self.availability = availability
    }

    /// A pick: Favorites shows these.
    public var isFlagged: Bool { flag == .pick }

    /// The color as one opaque RGBA8 pixel, the thumbnail the grid draws.
    public var pixel: [UInt8] {
        [color.c0, color.c1, color.c2].map { UInt8(($0 * 255).rounded()) } + [255]
    }

    /// The same photo at another pixel size (fakes use it for a crop's shape).
    func withSize(_ size: PixelSize) -> PhotoItem {
        PhotoItem(
            id: id, name: name, captureDate: captureDate, color: color, rating: rating, label: label, flag: flag,
            path: path, pixelSize: size, develop: develop, availability: availability)
    }

    /// The same photo under another id.
    func withID(_ newID: String) -> PhotoItem {
        PhotoItem(
            id: newID, name: name, captureDate: captureDate, color: color, rating: rating, label: label, flag: flag,
            path: path, pixelSize: pixelSize, develop: develop, availability: availability)
    }
}

/// View > Sort By. Ties fall back to the name, then the id, so every order is total.
/// The raw value is the menu title.
public enum LibrarySort: String, CaseIterable, Sendable, Hashable {
    case captureDate = "Capture Date", name = "Name", rating = "Rating"  // oldest, A to Z, most stars first

    /// True when `a` comes before `b` in this order.
    func orders(_ a: PhotoItem, before b: PhotoItem) -> Bool {
        switch self {
        case .captureDate where a.captureDate != b.captureDate: a.captureDate < b.captureDate
        case .rating where a.rating != b.rating: a.rating > b.rating
        default: a.name != b.name ? a.name < b.name : a.id < b.id
        }
    }
}

/// What the content area shows: the grid, or one photo in the loupe.
public enum LibraryMode: Sendable, Hashable { case grid, loupe }

/// Whether a photo's file can be read; `help` is the grid cell's tooltip.
public enum PhotoAvailability: Hashable, Sendable {
    case available
    case missing
    case unreadable(String)

    /// Nil while available; else what the cell's help says.
    public var help: String? {
        switch self {
        case .available: nil
        case .missing: "The file is missing."
        case .unreadable(let reason): "Library can't read this file: \(reason)."
        }
    }
}

extension PhotoItem {
    /// The loupe photo's and grid cell's accessibility value, e.g.
    /// "3 stars, Picked, Red"; "No stars" when unrated. Journeys read it.
    public var cullSummary: String {
        var parts = [rating == 0 ? "No stars" : rating == 1 ? "1 star" : "\(rating) stars"]
        if flag == .pick { parts.append("Picked") }
        if flag == .reject { parts.append("Rejected") }
        if let label { parts.append(label.rawValue) }
        return parts.joined(separator: ", ")
    }
}
