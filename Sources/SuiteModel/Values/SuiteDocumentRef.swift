// SuiteDocumentRef.swift: a document on disk as every process refers to it,
// with the one identity rule (`fileID`) and the file-name-safe key derived
// from it (`fileKey`). Foundation only for `Data`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A document on disk, as every app and the launcher refer to it.
public struct SuiteDocumentRef: Hashable, Codable, Sendable {
    public var path: String          // absolute path
    public var fileID: String        // `SuiteDocumentRef.fileID(forPath:)`, the one rule every process uses
    public var app: SuiteApp         // the app that last opened or saved it
    public var type: SuiteTypeID
    public var displayName: String   // file name with extension
    public var bookmark: Data?       // macOS bookmark data when the app has it; nil in tests and on Linux
    public init(path: String, fileID: String, app: SuiteApp, type: SuiteTypeID, displayName: String, bookmark: Data? = nil) {
        self.path = path; self.fileID = fileID; self.app = app; self.type = type
        self.displayName = displayName; self.bookmark = bookmark
    }

    /// The one identity rule (v1): the standardized absolute path. A moved file
    /// becomes a new entry; Locate… on the old card re-points it.
    public static func fileID(forPath path: String) -> String {
        var parts: [Substring] = []
        for p in path.split(separator: "/") where p != "." {
            if p == "..", !parts.isEmpty { parts.removeLast() } else if p != ".." { parts.append(p) }
        }
        return "path:/" + parts.joined(separator: "/")
    }

    /// A file id has slashes, so it never names a file; this does. FNV-1a
    /// 64-bit over the id's UTF-8 bytes, as 16 lowercase hex digits
    /// (thumbnails are `thumbnails/<fileKey>.png`).
    public static func fileKey(_ fileID: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in fileID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16, uppercase: false)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }
}
