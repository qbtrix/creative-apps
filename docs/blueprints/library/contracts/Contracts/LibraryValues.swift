// Contracts/LibraryValues.swift: the value types every Library contract
// shares. Linux-safe, Sendable, no pixels except DisplayImage's bytes.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A size in pixels. Both sides are at least 1 for a real photo.
public struct PixelSize: Hashable, Sendable, Codable {
    public var width: Int
    public var height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    public var longSide: Int { max(width, height) }
    /// This size scaled so its long side is at most `longSide`, never enlarged,
    /// each side at least 1. `longSide` under 1 is treated as 1.
    public func fitting(longSide limit: Int) -> PixelSize {
        let limit = max(limit, 1)
        guard longSide > limit, width > 0, height > 0 else { return self }
        let scale = Double(limit) / Double(longSide)
        return PixelSize(width: max(Int((Double(width) * scale).rounded()), 1),
                         height: max(Int((Double(height) * scale).rounded()), 1))
    }
}

/// A rectangle in whole pixels.
public struct PixelRect: Hashable, Sendable {
    public var x: Int, y: Int, width: Int, height: Int
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

/// Display bytes: sRGB, straight alpha, row-major, top row first, 4 bytes a
/// pixel (CoreRaster's `rgba8(colorSpace:)` layout).
public struct DisplayImage: Hashable, Sendable {
    public let size: PixelSize
    public let rgba8: [UInt8]
    /// Nil unless `rgba8.count == width * height * 4` and both sides are at least 1.
    public init?(size: PixelSize, rgba8: [UInt8]) {
        guard size.width >= 1, size.height >= 1,
              size.width.multipliedReportingOverflow(by: size.height).overflow == false,
              rgba8.count == size.width * size.height * 4 else { return nil }
        self.size = size
        self.rgba8 = rgba8
    }
    /// FNV-1a over the bytes as 16 hex digits: the loupe photo's checksum
    /// that journeys read. Computed on demand (only under the perf or test flag).
    public var checksum: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in rgba8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3 }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }
}

/// The image file types v1 imports. The raw value is the lowercased extension
/// set's first member.
public enum PhotoFileKind: String, Sendable, Codable, CaseIterable {
    case jpeg, png, heic
    /// The kind for a file name, matched without regard to case; nil for anything else.
    public static func kind(forFileName name: String) -> PhotoFileKind? {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return nil }
        switch name[name.index(after: dot)...].lowercased() {
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        case "heic", "heif": return .heic
        default: return nil
        }
    }
}

/// One file a folder scan found, read for metadata only.
public struct ImportCandidate: Hashable, Sendable {
    /// The absolute file path: the photo's id once imported.
    public var path: String
    /// Exif DateTimeOriginal, else the file's creation date.
    public var captureDate: Date
    /// After the Exif orientation is applied.
    public var pixelSize: PixelSize
    public var kind: PhotoFileKind
    public init(path: String, captureDate: Date, pixelSize: PixelSize, kind: PhotoFileKind) {
        self.path = path; self.captureDate = captureDate; self.pixelSize = pixelSize; self.kind = kind
    }
}

/// A file that could not be imported or exported, and why, in words for people.
public struct FileFailure: Hashable, Sendable {
    public var path: String
    public var reason: String
    public init(path: String, reason: String) {
        self.path = path; self.reason = reason
    }
}

/// What a folder scan found.
public struct FolderScan: Hashable, Sendable {
    public var candidates: [ImportCandidate]
    /// Image-named files whose metadata could not be read.
    public var failures: [FileFailure]
    public init(candidates: [ImportCandidate], failures: [FileFailure]) {
        self.candidates = candidates; self.failures = failures
    }
}

public struct ImportProgress: Hashable, Sendable {
    public var done: Int
    public var total: Int
    public init(done: Int, total: Int) {
        self.done = done; self.total = total
    }
    /// "Importing 3 of 27".
    public var text: String { "Importing \(min(done + 1, max(total, 1))) of \(max(total, 1))" }
}

public struct ImportResult: Hashable, Sendable {
    /// New photos, in capture-date order.
    public var added: [PhotoItem]
    /// Paths already in the catalog, skipped.
    public var alreadyKnown: Int
    public var failures: [FileFailure]
    public init(added: [PhotoItem], alreadyKnown: Int, failures: [FileFailure]) {
        self.added = added; self.alreadyKnown = alreadyKnown; self.failures = failures
    }
}

/// Every error a Library contract throws. `message` is the text the window shows.
public enum LibraryError: Error, Hashable, Sendable {
    case unreadableFolder(String)
    case noPhotos(String)
    case notAnImage(String)
    case missingFile(String)
    case damagedCatalog(String)
    case newerCatalog(version: Int)
    case invalid(String)
    case renderFailed(String)
    case writeFailed(path: String, reason: String)
    case cancelled

    public var message: String {
        switch self {
        case .unreadableFolder(let folder): "Library can't read \(folder). Check that you have access to it."
        case .noPhotos(let folder): "No photos found in \(folder)."
        case .notAnImage: "not an image file"
        case .missingFile(let path): "The file is missing: \(path)"
        case .damagedCatalog: "Library couldn't read its catalog and started a new one. The old file is catalog.json.bad."
        case .newerCatalog: "This catalog was made by a newer Library. Update Library to open it."
        case .invalid(let detail): detail
        case .renderFailed(let reason): "Couldn't render this photo: \(reason)."
        case .writeFailed(_, let reason): reason
        case .cancelled: "Cancelled."
        }
    }
}

/// How the fakes behave; `-LibraryFakeMode`.
public enum FakeMode: String, Sendable, CaseIterable {
    case ok, fail, slow
}
