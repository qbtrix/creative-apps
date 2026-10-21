// LibraryFolders+Kernel.swift (folders FO-2 stubs, FO-5 bodies): the FOLDERS tree as two command specs, so
// the sidebar, the afterglow CLI and an agent browse folders one way. `folders.list` is a query returning the
// tree as rows in pre-order, each with its `depth` (the schema builders can't nest a node in itself);
// `view.show-folder` shows one folder's photos, with or without its subfolders', as view state, not an undo
// step. Both are unavailable on an empty catalog. Until FO-5 builds the bodies and appends `folderSpecs` to
// `commands`, they say folders aren't built and their runs throw `notBuilt`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension LibraryCatalog {
    /// view.show-folder's folder and whether its subfolders' photos show too (default true).
    struct ShowFolderParams: Codable, Sendable { var path: String; var subfolders: Bool? }

    /// Why the folder commands can't run: no photos, or the stub's not-built reason (FO-5 drops it).
    static let noFolders = "Import a folder to see its folders.", foldersNotBuilt = "Folders arrive with FO-4."

    /// The feature a folder stub's `notBuilt` names.
    static let foldersFeature = "folders FO-5"

    /// Why a folder command can't run on `catalog`. Stub: with photos, folders aren't built.
    static func folderHelp(_ catalog: LibraryCatalog) -> String? {
        catalog.isEmpty ? noFolders : foldersNotBuilt
    }

    /// One `folders.list` row: a FolderNode without its children, at its depth in the tree.
    static let folderRow = ParamSchema.object([
        "path": .string("The folder's path on disk."), "name": .string("The row's name; a collapsed chain reads a/b/c."),
        "depth": .integer("0 for an import's root, one more per level below it.", minimum: 0),
        "ownCount": .integer("Photos directly in the folder.", minimum: 0),
        "totalCount": .integer("Photos in the folder and every subfolder.", minimum: 0),
        "allMissing": .boolean,
    ], required: ["path", "name", "depth", "ownCount", "totalCount", "allMissing"])

    /// folders.list and view.show-folder. FO-5 appends them to `commands`.
    static let folderSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("folders.list", title: "List Folders",
               summary: "The folders the catalog's photos sit in, one root per import, as rows in pre-order with their counts.",
               kind: .query, params: NoParams.self, schema: ParamSchema.none,
               result: .object(["folders": .array(of: folderRow)], required: ["folders"]), example: .object([:]),
               availability: { available(folderHelp($0)) }) { _, _ -> JSONValue in
            throw CatalogError.notBuilt(id: "folders.list", feature: foldersFeature)
        },
        .typed("view.show-folder", title: "Show Folder",
               summary: "Shows one folder's photos in the grid, with its subfolders' photos unless subfolders is false.",
               kind: .view, params: ShowFolderParams.self,
               schema: .object([
                   "path": .string("A folder path folders.list returned."),
                   "subfolders": .optional(.boolean),
               ], required: ["path"]),
               example: .object(["path": .string("/Photos/trips"), "subfolders": .bool(false)]),
               availability: { available(folderHelp($0)) }) { _, _ -> JSONValue in
            throw CatalogError.notBuilt(id: "view.show-folder", feature: foldersFeature)
        },
    ]
}
