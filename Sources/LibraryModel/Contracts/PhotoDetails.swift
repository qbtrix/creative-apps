// Contracts/PhotoDetails.swift: what the camera recorded for a photo, and the
// Info tab's camera rows (metadata-more MD-1; the tag reading, display texts
// and rows are MD-6's). Linux-safe value types.
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
    /// "FocalLength"). ISO is a list (its first) or one number; a tag of
    /// the wrong kind is ignored.
    public init(exif: [String: Any], tiff: [String: Any]) {
        let iso = exif["ISOSpeedRatings"]
        self.init(
            make: tiff["Make"] as? String, model: tiff["Model"] as? String, lens: exif["LensModel"] as? String,
            iso: (iso as? [Int])?.first ?? iso as? Int,
            exposureTime: Self.number(exif["ExposureTime"]), fNumber: Self.number(exif["FNumber"]),
            focalLength: Self.number(exif["FocalLength"]))
    }

    /// True when the file said nothing usable.
    public var isEmpty: Bool { self == .none }

    /// "Fixture Optics FX-1" (the make left off when the model starts with it, any case).
    public var cameraText: String? {
        guard let make else { return model }
        guard let model else { return make }
        return model.lowercased().hasPrefix(make.lowercased()) ? model : make + " " + model
    }
    /// "1/250 s" or "2.5 s".
    public var shutterText: String? { exposureTime.map { Self.shutter($0) + " s" } }
    /// "f/2.8" or "f/8".
    public var apertureText: String? { fNumber.map(Self.aperture) }
    /// "35 mm".
    public var focalText: String? { focalLength.map { Self.decimal($0) + " mm" } }
    /// "ISO 400".
    public var isoText: String? { iso.map { "ISO \($0)" } }

    /// A tag's number: a Double or an Int; nil for anything else.
    static func number(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        return (value as? Int).map(Double.init)
    }

    /// One decimal, ".0" dropped: 2.8 → "2.8", 2.0 → "2" (locale-independent).
    static func decimal(_ value: Double) -> String {
        ExportSidecar.number((value * 10).rounded() / 10)
    }

    /// "1/250" when 1/n is within 5% of `seconds`, else "0.3" or "2.5" (no unit).
    static func shutter(_ seconds: Double) -> String {
        guard seconds < 1 else { return decimal(seconds) }
        let n = (1 / seconds).rounded()
        guard n.isFinite, n <= 1_000_000, abs(1 / n - seconds) / seconds < 0.05 else { return decimal(seconds) }
        return "1/\(Int(n))"
    }

    static func aperture(_ fNumber: Double) -> String { "f/" + decimal(fNumber) }

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
    /// value, a range ("ISO 100–3200"), or a count ("2 cameras"). None, not
    /// even Taken, when no photo has camera details ("No camera details").
    public static func rows(for photos: [PhotoItem]) -> [CameraRow] {
        guard photos.contains(where: { !$0.camera.isEmpty }) else { return [] }
        return CameraField.allCases.compactMap { row($0, photos) }
    }

    private static func row(_ field: CameraField, _ photos: [PhotoItem]) -> CameraRow? {
        let cameras = photos.map(\.camera)
        switch field {
        case .camera: return named(field, cameras.compactMap(\.cameraText), key: "camera", plural: "cameras")
        case .lens: return named(field, cameras.compactMap(\.lens), key: "lens", plural: "lenses")
        case .aperture: return ranged(field, cameras.compactMap(\.fNumber), CameraDetails.aperture) { $0 }
        case .shutter: return ranged(field, cameras.compactMap(\.exposureTime), CameraDetails.shutter) { $0 + " s" }
        case .iso: return ranged(field, cameras.compactMap(\.iso), { String($0) }) { "ISO " + $0 }
        case .focalLength: return ranged(field, cameras.compactMap(\.focalLength), CameraDetails.decimal) { $0 + " mm" }
        case .taken:
            let dates = photos.map(\.captureDate)
            guard let first = dates.min(), let last = dates.max() else { return nil }
            return CameraRow(field: field, value: .dates(first, last), search: nil)
        }
    }

    /// One name with the search that finds it, or a count ("3 lenses"); nil with no names.
    private static func named(_ field: CameraField, _ names: [String], key: String, plural: String) -> CameraRow? {
        guard let name = names.first else { return nil }
        let distinct = Set(names).count
        guard distinct > 1 else { return CameraRow(field: field, value: .text(name), search: "\(key):\"\(name)\"") }
        return CameraRow(field: field, value: .text("\(distinct) \(plural)"), search: nil)
    }

    /// The lowest to the highest value, each as `each`, wrapped in `whole`
    /// ("ISO 100–3200"); one value when both ends read the same.
    private static func ranged<T: Comparable>(
        _ field: CameraField, _ values: [T], _ each: (T) -> String, whole: (String) -> String
    ) -> CameraRow? {
        guard let low = values.min(), let high = values.max() else { return nil }
        let (from, to) = (each(low), each(high))
        return CameraRow(field: field, value: .text(whole(from == to ? from : from + "–" + to)), search: nil)
    }
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
