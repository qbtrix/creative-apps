// Contracts/ExportFormats.swift (EX-1 slot, filled by EX-7): the raster formats an export
// writes. Library-local: no shared module holds export formats yet. Extension final.

/// A file format an export writes; the raw value is the sheet's label.
public enum ExportFormat: String, CaseIterable, Sendable, Codable {
    case jpeg = "JPEG", png = "PNG", tiff = "TIFF", heic = "HEIC"

    /// The written name's extension (final).
    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .tiff: "tif"
        case .heic: "heic"
        }
    }

    /// Whether the Quality row applies. Slot: true; EX-7 makes it JPEG and HEIC only.
    public var usesQuality: Bool { true }

    /// The format a written name ends in. Slot: jpg and jpeg only, any case.
    public static func forFileName(_ name: String) -> ExportFormat? {
        guard let dot = name.lastIndex(of: ".") else { return nil }
        let ext = name[name.index(after: dot)...].lowercased()
        return ext == "jpg" || ext == "jpeg" ? .jpeg : nil
    }

    /// Why `self` can't be chosen, nil when it can. Slot: only JPEG can.
    public func help(writable: Set<ExportFormat>) -> String? {
        self == .jpeg ? nil : "Other formats aren't built yet (export formats)."
    }
}
