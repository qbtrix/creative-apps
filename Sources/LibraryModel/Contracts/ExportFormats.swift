// Contracts/ExportFormats.swift (EX-1 slot, filled by EX-7): export formats, Library-local (#3091).

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

    /// Whether the Quality row applies: only the lossy formats, JPEG and HEIC.
    public var usesQuality: Bool {
        switch self {
        case .jpeg, .heic: true
        case .png, .tiff: false
        }
    }

    /// The format a written name ends in: jpg, jpeg, png, tif, tiff or heic, any case.
    public static func forFileName(_ name: String) -> ExportFormat? {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        switch name[name.index(after: dot)...].lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "tif", "tiff": return .tiff
        case "heic": return .heic
        default: return nil
        }
    }

    /// Why `self` can't be chosen, nil when this Mac can write it.
    public func help(writable: Set<ExportFormat>) -> String? {
        writable.contains(self) ? nil : "This Mac can't write \(rawValue) files."
    }
}
