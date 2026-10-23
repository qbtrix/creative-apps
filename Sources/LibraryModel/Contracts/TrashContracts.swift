// Contracts/TrashContracts.swift: the Trash (cull-finish DR-1). Delete
// Rejects never deletes a file: it moves each reject to the Trash through
// `LibraryServices.trash` and moves it back on undo. `.fake` holds
// `FakeTrash` (moves in memory), `.live` holds `LiveTrash`
// (`FileManager.trashItem`, DR-8). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Moves photo files to the Trash and back. Live: `LiveTrash`. Fake: `FakeTrash`.
public protocol PhotoTrashing: Sendable {
    /// Moves the file at `path` to the Trash; returns where it went. Throws when it can't (missing, no rights).
    func moveToTrash(_ path: String) throws -> String
    /// Moves `trashed` back to `path`; throws when the Trash no longer has it or `path` is taken.
    func putBack(_ trashed: String, to path: String) throws
}
