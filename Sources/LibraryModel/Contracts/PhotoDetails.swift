// Contracts/PhotoDetails.swift: what the camera recorded for a photo, and the
// Info tab's camera rows (metadata-more MD-1; the tag reading, display texts
// and rows are filled by MD-6). Linux-safe value types.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What the camera recorded (CIPA DC-008 Exif and TIFF tags). The init trims
/// spaces and NULs, turns empty text into nil, and drops any number that is
/// not finite or not above 0.
public struct CameraDetails: Hashable, Sendable {
    public var make: String?, model: String?, lens: String?
    public var iso: Int?
    public var exposureTime: Double?  // seconds
    public var fNumber: Double?
    public var focalLength: Double?  // mm

    /// No details: samples and files without Exif.
    public static let none = CameraDetails()

    public init(
        make: String? = nil, model: String? = nil, lens: String? = nil, iso: Int? = nil,
        exposureTime: Double? = nil, fNumber: Double? = nil, focalLength: Double? = nil
    ) {
        self.make = Self.text(make)
        self.model = Self.text(model)
        self.lens = Self.text(lens)
        self.iso = iso.flatMap { $0 > 0 ? $0 : nil }
        self.exposureTime = Self.positive(exposureTime)
        self.fNumber = Self.positive(fNumber)
        self.focalLength = Self.positive(focalLength)
    }

    /// From ImageIO's Exif and TIFF dictionaries, keyed by tag name ("Make",
    /// "Model", "LensModel", "ISOSpeedRatings", "ExposureTime", "FNumber",
    /// "FocalLength"). MD-1: returns `.none`; MD-6 reads the tags.
    public init(exif: [String: Any], tiff: [String: Any]) {
        self = .none
    }

    /// True when the file said nothing usable.
    public var isEmpty: Bool { self == .none }

    /// "Fixture Optics FX-1" (the make left off when the model starts with it). MD-1: nil; MD-6.
    public var cameraText: String? { nil }
    /// "1/250 s" or "2.5 s". MD-1: nil; MD-6.
    public var shutterText: String? { nil }
    /// "f/2.8" or "f/8". MD-1: nil; MD-6.
    public var apertureText: String? { nil }
    /// "35 mm". MD-1: nil; MD-6.
    public var focalText: String? { nil }
    /// "ISO 400". MD-1: nil; MD-6.
    public var isoText: String? { nil }

    /// `value` without leading and trailing spaces and NULs; nil when nothing is left.
    static func text(_ value: String?) -> String? {
        guard let value else { return nil }
        let isPadding: (Character) -> Bool = { $0.isWhitespace || $0 == "\0" }
        guard let first = value.firstIndex(where: { !isPadding($0) }),
              let last = value.lastIndex(where: { !isPadding($0) }) else { return nil }
        return String(value[first...last])
    }

    /// `value` when it is finite and above 0, else nil.
    static func positive(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

/// The Info tab's rows, most-used first (inferred: what the photo is, then
/// the exposure, then when).
public enum CameraField: String, CaseIterable, Sendable {
    case camera = "Camera", lens = "Lens", aperture = "Aperture", shutter = "Shutter",
         iso = "ISO", focalLength = "Focal Length", taken = "Taken"
}

/// One row's value: a text, or the span of capture dates.
public enum CameraRowValue: Hashable, Sendable { case text(String), dates(Date, Date) }

/// One Info tab row.
public struct CameraRow: Hashable, Sendable {
    public let field: CameraField
    public let value: CameraRowValue
    /// The search that finds this value (`lens:"50mm F1.8"`); nil for ranges and dates.
    public let search: String?
}

extension CameraRow {
    /// One row per field any photo has, in `CameraField` order: a shared
    /// value, a range ("ISO 100–3200"), or a count ("2 cameras"). MD-1: []; MD-6.
    public static func rows(for photos: [PhotoItem]) -> [CameraRow] { [] }
}

extension LibraryCatalog {
    /// The selected photos in the sort order (what the inspector shows).
    public var selectedPhotos: [PhotoItem] {
        guard !selection.isEmpty else { return [] }
        return sortedItems.filter { selection.contains($0.id) }
    }

    /// The Info tab's camera rows for the selection.
    public var selectedCameraRows: [CameraRow] { CameraRow.rows(for: selectedPhotos) }
}

extension MetadataInspectorID {
    /// The Info tab's row for `field`, e.g. "library.metadata.camera.lens".
    public static func camera(_ field: CameraField) -> String {
        "library.metadata.camera.\(field)"
    }
}
