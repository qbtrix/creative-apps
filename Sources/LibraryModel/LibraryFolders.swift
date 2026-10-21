// LibraryFolders.swift (folders FO-1 stub, FO-4 body): the catalog's photos as the folders they sit in on
// disk, for the sidebar's FOLDERS section. Each import is a root; a chain of folders that hold no photos of
// their own until the last one collapses into one row (`a/b/c`). `ownCount` counts a folder's own photos,
// `totalCount` adds its descendants'. A folder is a child of another only at a `/` boundary, so `/a/bc`
// never sits under `/a/b`. `allMissing` is true when every photo under it is missing from disk. Until FO-4
// builds the body, `tree` returns no folders. Linux-safe.
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
}
