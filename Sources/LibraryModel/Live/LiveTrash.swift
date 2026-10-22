// Live/LiveTrash.swift: the live Trash (cull-finish). DR-1's stub: every
// call throws `unavailable`, which disables Delete Rejects with that reason.
// DR-8 gives it `FileManager.trashItem` and the move back on macOS; on Linux
// it stays unavailable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveTrash: PhotoTrashing {
    public static let unavailable: String? = "Moving to the Trash isn't connected yet (cull-finish)."
    public init() {}

    public func moveToTrash(_ path: String) throws -> String {
        throw LibraryError.invalid(Self.unavailable ?? "")
    }

    public func putBack(_ trashed: String, to path: String) throws {
        throw LibraryError.invalid(Self.unavailable ?? "")
    }
}
