// Live/LiveTrash.swift: the live Trash (cull-finish DR-8). On macOS a reject
// goes to the Trash through `FileManager.trashItem`, which names where it
// went (the name can change there), and undo moves it back, never over a file
// that took its place. Nothing here deletes a file. Linux has no Trash: the
// service is unavailable with its reason, which disables Delete Rejects.
#if canImport(Darwin)
import Foundation
#elseif canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveTrash: PhotoTrashing {
    #if canImport(Darwin)
    public static let unavailable: String? = nil
    #else
    public static let unavailable: String? = "Moving to the Trash needs macOS."
    #endif
    public init() {}

    public func moveToTrash(_ path: String) throws -> String {
        #if canImport(Darwin)
        guard FileManager.default.fileExists(atPath: path) else { throw LibraryError.missingFile(path) }
        var trashed: NSURL?
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashed)
        } catch {
            throw LibraryError.writeFailed(path: path, reason: "Couldn't move it to the Trash.")
        }
        guard let trashedPath = (trashed as URL?)?.path else {
            throw LibraryError.writeFailed(path: path, reason: "The Trash didn't say where it went.")
        }
        return trashedPath
        #else
        throw LibraryError.invalid(Self.unavailable ?? "")
        #endif
    }

    public func putBack(_ trashed: String, to path: String) throws {
        #if canImport(Darwin)
        guard FileManager.default.fileExists(atPath: trashed) else { throw LibraryError.missingFile(trashed) }
        guard !FileManager.default.fileExists(atPath: path) else {
            throw LibraryError.writeFailed(path: path, reason: "Another file is already at \(path).")
        }
        do {
            try FileManager.default.moveItem(atPath: trashed, toPath: path)
        } catch {
            throw LibraryError.writeFailed(path: path, reason: "Couldn't move it back from the Trash.")
        }
        #else
        throw LibraryError.invalid(Self.unavailable ?? "")
        #endif
    }
}
