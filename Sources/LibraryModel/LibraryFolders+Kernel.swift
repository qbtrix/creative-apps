// LibraryFolders+Kernel.swift (folders FO-2 stubs, FO-5 bodies): the FOLDERS tree as two command specs, so
// the sidebar, the afterglow CLI and an agent browse folders one way. `folders.list` is a query returning the
// tree as rows in pre-order, each with its `depth` (the schema builders can't nest a node in itself);
// `view.show-folder` sets the filter's folder rule (`FolderScope`) to one folder, with or without its
// subfolders, as view state, not an undo step, and refuses a path that isn't in the tree. Both are unavailable
// while no photo sits in a folder. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// The filter's folder rule: a photo shows when its folder is `path`, or with `subfolders` sits anywhere below it.
public struct FolderScope: Hashable, Sendable {
    /// The folder's path on disk, as FolderNode.path has it.
    public var path: String
    /// Whether the photos of the folder's subfolders show too.
    public var subfolders: Bool

    public init(path: String, subfolders: Bool) { (self.path, self.subfolders) = (path, subfolders) }

    /// Whether `photo` sits in the folder, or below it when `subfolders` is on. Below means at a `/`, so a rule
    /// on `/a/b` never admits `/a/bc`. A photo without an absolute path sits in no folder.
    public func admits(_ photo: PhotoItem) -> Bool {
        guard let parent = Self.folder(of: photo) else { return false }
        if parent == path { return true }
        return subfolders && parent.hasPrefix(path.hasSuffix("/") ? path : path + "/")
    }

    /// The folder `photo` sits in, as LibraryFolders.tree cuts it.
    static func folder(of photo: PhotoItem) -> String? {
        guard let path = photo.path, path.hasPrefix("/"), let slash = path.lastIndex(of: "/") else { return nil }
        return slash == path.startIndex ? "/" : String(path[..<slash])
    }

    /// The rule in the filter bar's summary: "In trips" or "In trips and its subfolders".
    var summaryPhrase: String {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return "In \(name)" + (subfolders ? " and its subfolders" : "")
    }
}

extension LibraryCatalog {
    /// view.show-folder's folder and whether its subfolders' photos show too (default true).
    struct ShowFolderParams: Codable, Sendable { var path: String; var subfolders: Bool? }

    /// Why the folder commands can't run: no photo sits in a folder.
    static let noFolders = "Import a folder to see its folders."

    /// Why a folder command can't run on `catalog`: nil once a photo sits in a folder.
    static func folderHelp(_ catalog: LibraryCatalog) -> String? {
        catalog.items.contains { FolderScope.folder(of: $0) != nil } ? nil : noFolders
    }

    /// `nodes` and their descendants as folders.list rows, in pre-order.
    static func folderRows(_ nodes: [FolderNode], depth: Int = 0) -> [JSONValue] {
        nodes.flatMap { node -> [JSONValue] in
            let row: JSONValue = .object([
                "path": .string(node.path), "name": .string(node.name), "depth": .number(Double(depth)),
                "ownCount": .number(Double(node.ownCount)), "totalCount": .number(Double(node.totalCount)),
                "allMissing": .bool(node.allMissing),
            ])
            return [row] + folderRows(node.children, depth: depth + 1)
        }
    }

    /// Whether `path` is a folder in `nodes` or below them.
    static func hasFolder(_ path: String, in nodes: [FolderNode]) -> Bool {
        nodes.contains { $0.path == path || hasFolder(path, in: $0.children) }
    }

    /// Shows the folder at `path`, with its subfolders' photos when `subfolders`, keeping the filter's other rules.
    mutating func showFolder(_ path: String, subfolders: Bool) throws {
        guard Self.hasFolder(path, in: LibraryFolders.tree(items)) else {
            throw CatalogError.unavailable(id: "view.show-folder", why: "There is no folder \(path).")
        }
        var next = activeFilter
        next.folder = FolderScope(path: path, subfolders: subfolders)
        setFilter(next)
    }

    /// One `folders.list` row: a FolderNode without its children, at its depth in the tree.
    static let folderRow = ParamSchema.object([
        "path": .string("The folder's path on disk."), "name": .string("The row's name; a collapsed chain reads a/b/c."),
        "depth": .integer("0 for an import's root, one more per level below it.", minimum: 0),
        "ownCount": .integer("Photos directly in the folder.", minimum: 0),
        "totalCount": .integer("Photos in the folder and every subfolder.", minimum: 0),
        "allMissing": .boolean,
    ], required: ["path", "name", "depth", "ownCount", "totalCount", "allMissing"])

    /// folders.list and view.show-folder, appended to `commands`.
    static let folderSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("folders.list", title: "List Folders",
               summary: "The folders the catalog's photos sit in, one root per import, as rows in pre-order with their counts.",
               kind: .query, params: NoParams.self, schema: ParamSchema.none,
               result: .object(["folders": .array(of: folderRow)], required: ["folders"]), example: .object([:]),
               availability: { available(folderHelp($0)) }) { c, _ -> JSONValue in
            .object(["folders": .array(folderRows(LibraryFolders.tree(c.items)))])
        },
        .typed("view.show-folder", title: "Show Folder",
               summary: "Shows one folder's photos in the grid, with its subfolders' photos unless subfolders is false.",
               kind: .view, params: ShowFolderParams.self,
               schema: .object([
                   "path": .string("A folder path folders.list returned."),
                   "subfolders": .optional(.boolean),
               ], required: ["path"]),
               example: .object(["path": .string("/Photos/trips"), "subfolders": .bool(false)]),
               availability: { available(folderHelp($0)) }) { c, p -> JSONValue in
            try c.showFolder(p.path, subfolders: p.subfolders ?? true)
            return .object([:])
        },
    ]
}
