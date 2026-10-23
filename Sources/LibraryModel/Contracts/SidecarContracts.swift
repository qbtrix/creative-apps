// Contracts/SidecarContracts.swift (metadata-more MD-2): the XMP sidecar Library
// keeps beside each photo file. The writer is a contract like `JPEGWriting`
// (its errors are `LibraryError`); `.live` holds `UnconnectedSidecars` until
// the window passes its platform writer. `SidecarFields` is what a sidecar
// says; the rating follows XMP Basic as `ExportSidecar` does, -1 for a reject.
// The packet itself is MD-15's `XMPSidecar`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Writes XMP sidecars beside photo files. Live: `XMPSidecarWriter`
/// (LibraryApp/Platform). Fake: `FakeSidecars` (in memory).
public protocol SidecarWriting: Sendable {
    /// The sidecar's bytes; nil when there is none.
    func read(sidecar path: String) async throws -> Data?
    /// Writes `data` to `path` atomically. Throws `writeFailed` when `path`
    /// is not a `.xmp` file, is an image file, or holds a sidecar Library
    /// didn't write. Never opens any other file for writing.
    func write(_ data: Data, sidecar path: String) async throws
}

/// `.live`'s default until the window passes `XMPSidecarWriter`: every call
/// throws `invalid(unavailable)`.
public struct UnconnectedSidecars: SidecarWriting {
    public static let unavailable = "Writing sidecars isn't connected yet (metadata-more)."
    public init() {}
    public func read(sidecar path: String) async throws -> Data? { throw LibraryError.invalid(Self.unavailable) }
    public func write(_ data: Data, sidecar path: String) async throws { throw LibraryError.invalid(Self.unavailable) }
}

/// What a sidecar says about one photo: the fields it shares with other tools.
public struct SidecarFields: Hashable, Sendable {
    public var keywords: [String], title: String, caption: String
    public var rating: Int  // 0...5, or -1 for a reject (the XMP Basic rule)
    public var label: PhotoLabel?

    public init(photo: PhotoItem) {
        keywords = photo.keywords; title = photo.title; caption = photo.caption
        rating = photo.flag == .reject ? -1 : photo.rating
        label = photo.label
    }

    /// Nothing to say: no keywords, title, caption, rating or label.
    public var isEmpty: Bool { keywords.isEmpty && title.isEmpty && caption.isEmpty && rating == 0 && label == nil }
}

/// One sidecar to write: the photo, where, what it says, and its bytes.
public struct SidecarWrite: Hashable, Sendable {
    public var photoID: String, path: String, fields: SidecarFields, data: Data
    public init(photoID: String, path: String, fields: SidecarFields, data: Data) {
        self.photoID = photoID; self.path = path; self.fields = fields; self.data = data
    }
}
