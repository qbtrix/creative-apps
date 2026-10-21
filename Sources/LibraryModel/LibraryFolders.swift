// LibraryFolders.swift (folders FO-1 stub, FO-4 body): the catalog's photos as the folders they sit in on
// disk, for the sidebar's FOLDERS section. Each import is a root; a chain of folders that hold no photos of
// their own until the last one collapses into one row (`a/b/c`). `ownCount` counts a folder's own photos,
// `totalCount` adds its descendants'. A folder is a child of another only at a `/` boundary, so `/a/bc`
// never sits under `/a/b`. `allMissing` is true when every photo under it is missing from disk. Until FO-4
// builds the body, `tree` returns no folders. The sidebar reads `folderTree`, `showFolderHelp` and each row's
// `rowID`, `library.folder.` and the path's FNV-1a hash (FO-3). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One folder in the FOLDERS tree: its path, its row's name and its photo counts.
public struct FolderNode: Hashable, Sendable, Identifiable {
    public var id: String { path }
    /// The folder's path on disk, without a trailing `/`.
    public var path: String
    /// The row's name: the last component, or a collapsed chain such as `a/b/c`.
    public var name: String
    /// Photos directly in this folder, and those plus every descendant's.
    public var ownCount: Int, totalCount: Int
    /// True when every photo under this folder is missing from disk.
    public var allMissing: Bool
    /// The subfolders that hold photos, sorted by name.
    public var children: [FolderNode]

    public init(path: String, name: String, ownCount: Int, totalCount: Int, allMissing: Bool, children: [FolderNode]) {
        (self.path, self.name, self.ownCount, self.totalCount) = (path, name, ownCount, totalCount)
        (self.allMissing, self.children) = (allMissing, children)
    }
}

/// Builds the FOLDERS tree from the catalog's photos.
public enum LibraryFolders {
    /// The folders `photos` sit in, one root per import, sorted by name. Stub: none until FO-4.
    public static func tree(_ photos: [PhotoItem]) -> [FolderNode] {
        []
    }

    /// What every FOLDERS row's id starts with; a collection's id never does.
    public static let rowPrefix = "library.folder."

    /// The FOLDERS row id for `path`: the prefix and the path's FNV-1a 64-bit hash as 16 hex digits, the same in
    /// every process (Swift's Hasher is seeded per launch).
    public static func rowID(for path: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16)
        return rowPrefix + String(repeating: "0", count: max(0, 16 - hex.count)) + hex
    }

    /// True when `id` is a FOLDERS row's, not a collection's.
    public static func isRowID(_ id: String) -> Bool {
        id.hasPrefix(rowPrefix) && id.count == rowPrefix.count + 16
    }
}

extension LibraryCatalog {
    /// The FOLDERS tree of the catalog's photos, for the sidebar.
    public var folderTree: [FolderNode] { LibraryFolders.tree(items) }

    /// Why view.show-folder can't run; nil when a folder row's click can show it.
    public var showFolderHelp: String? { Self.folderHelp(self) }
}
