// Fakes/FakeTrash.swift: the Trash in memory (cull-finish DR-1). A move
// records the path under ".Trash/<name>" and a put-back removes it, so tests
// read back what moved. `failing` names paths whose move throws, and
// `.fail` mode refuses every call. Never touches the file system.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class FakeTrash: PhotoTrashing {
    let mode: FakeMode
    let failing: Set<String>
    private let state = Mutex<[String: String]>([:])  // trashed path → original path

    public init(mode: FakeMode = .ok, failing: Set<String> = []) {
        self.mode = mode; self.failing = failing
    }

    /// What sits in the Trash now: trashed path → the path it came from.
    public var moved: [String: String] { state.withLock { $0 } }

    public func moveToTrash(_ path: String) throws -> String {
        guard mode != .fail, !failing.contains(path) else {
            throw LibraryError.writeFailed(path: path, reason: "The file couldn't be moved to the Trash.")
        }
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return state.withLock { moved in
            var trashed = ".Trash/" + name
            var suffix = 2
            while moved[trashed] != nil {
                trashed = ".Trash/\(name) \(suffix)"
                suffix += 1
            }
            moved[trashed] = path
            return trashed
        }
    }

    public func putBack(_ trashed: String, to path: String) throws {
        try state.withLock { moved in
            guard mode != .fail, moved[trashed] != nil else { throw LibraryError.missingFile(trashed) }
            guard !moved.values.contains(path) || moved[trashed] == path else {
                throw LibraryError.writeFailed(path: path, reason: "A file is already there.")
            }
            moved[trashed] = nil
        }
    }
}
