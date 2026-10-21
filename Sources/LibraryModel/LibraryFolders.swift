// LibraryFolders.swift (folders FO-1 stub, FO-4 body): the catalog's photos as the folders they sit in on
// disk, for the sidebar's FOLDERS section. Each import is a root; a chain of folders that hold no photos of
// their own until the last one collapses into one row (`a/b/c`). `ownCount` counts a folder's own photos,
// `totalCount` adds its descendants'. A folder is a child of another only at a `/` boundary, so `/a/bc`
// never sits under `/a/b`. `allMissing` is true when every photo under it is missing from disk. The tree keeps
// only folders that hold photos and folders where two such branches meet, so a chain collapses by itself and
// the photo-less folders above every import fall away, leaving one root per import. The sidebar reads
// `folderTree`, `showFolderHelp` and each row's `rowID`, `library.folder.` and the path's FNV-1a hash (FO-3).
// Linux-safe.
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
    /// A folder's own photos and how many of them are missing from disk.
    typealias Tally = [String: (own: Int, missing: Int)]

    /// The folders `photos` sit in, one root per import, sorted by name. A photo without an absolute path
    /// (a generated sample) sits in no folder.
    public static func tree(_ photos: [PhotoItem]) -> [FolderNode] {
        var tally: Tally = [:]
        for photo in photos {
            guard let path = photo.path, path.hasPrefix("/"), let slash = path.lastIndex(of: "/") else { continue }
            let folder = slash == path.startIndex ? "/" : String(path[..<slash])
            tally[folder, default: (0, 0)].own += 1
            if photo.availability == .missing { tally[folder, default: (0, 0)].missing += 1 }
        }
        let sorted = tally.keys.sorted(by: precedes)
        var kept = Set(sorted)
        for (a, b) in zip(sorted, sorted.dropFirst()) {
            if let meet = commonFolder(a, b) { kept.insert(meet) }
        }
        return build(kept.sorted(by: precedes), tally)
    }

    /// Path order with `/` before every other character, so a folder's subfolders follow it directly.
    static func precedes(_ a: String, _ b: String) -> Bool {
        a.utf8.lexicographicallyPrecedes(b.utf8) { ($0 == 47 ? 0 : $0) < ($1 == 47 ? 0 : $1) }
    }

    /// The deepest folder holding both `a` and `b`, cut at a `/`; nil when only `/` holds both.
    static func commonFolder(_ a: String, _ b: String) -> String? {
        let x = Array(a.utf8), y = Array(b.utf8)
        var n = 0
        while n < x.count, n < y.count, x[n] == y[n] { n += 1 }
        let atBoundary = (n == x.count || x[n] == 47) && (n == y.count || y[n] == 47)
        if !atBoundary { n = x[..<n].lastIndex(of: 47) ?? 0 }
        return n > 0 ? String(decoding: x[..<n], as: UTF8.self) : nil
    }

    /// Nests `folders`, sorted by `precedes`, into nodes: each folder is a child of the nearest earlier one it
    /// sits inside, the rest are roots. Total counts and `allMissing` roll up as each folder closes.
    static func build(_ folders: [String], _ tally: Tally) -> [FolderNode] {
        var roots: [FolderNode] = []
        var open: [(node: FolderNode, missing: Int)] = []
        func close() {
            guard var last = open.popLast() else { return }
            last.node.allMissing = last.missing == last.node.totalCount
            guard !open.isEmpty else { roots.append(last.node); return }
            open[open.count - 1].node.children.append(last.node)
            open[open.count - 1].node.totalCount += last.node.totalCount
            open[open.count - 1].missing += last.missing
        }
        for path in folders {
            while let top = open.last?.node.path, !path.hasPrefix(top + "/") { close() }
            let parent = open.last?.node.path
            let name = parent.map { String(path.dropFirst($0.count + 1)) } ?? (path == "/" ? path : String(path.dropFirst()))
            let own = tally[path] ?? (0, 0)
            let node = FolderNode(path: path, name: name, ownCount: own.own, totalCount: own.own, allMissing: false,
                                  children: [])
            open.append((node, own.missing))
        }
        while !open.isEmpty { close() }
        return roots
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
