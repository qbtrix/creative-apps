// LibraryCatalogFiles+Kernel.swift (catalog-files LC-1 stubs, LC-6 bodies): Remove from Catalog and Relink as
// kernel specs, one undo step each, neither deleting a file; `file.import` takes `importSchema`. LC-1: both are
// unavailable with the reason and every run throws `CatalogError.notBuilt`. Linux-safe.
import SuiteKernel

extension LibraryCatalog {
    /// Why Copy on import, Remove from Catalog and Relink are off until their bodies land, in the controls' words.
    public static let catalogFilesHelp = "File management arrives with LC-5."

    struct RemoveFromCatalogParams: Codable, Sendable { var ids: [String]? }
    struct RelinkParams: Codable, Sendable { var id: String; var file: String }

    /// `file.import`'s params: the folder, and the copy choice (`copyTo` left out adds in place).
    public static let importSchema = ParamSchema.object([
        "folder": .string("The folder to import."),
        "copyTo": .optional(.string("The folder the photos are copied into; left out adds them in place.")),
        "byDate": .optional(.boolean),
    ], required: ["folder"])

    /// `photo.remove-from-catalog` and `photo.relink`; LC-6 appends them to `commands` and the ledger.
    public static let catalogFileSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("photo.remove-from-catalog", title: "Remove from Catalog",
               summary: "Removes the photos (the selection when ids is left out) from the catalog. Their files stay on disk.",
               kind: .edit, params: RemoveFromCatalogParams.self,
               schema: .object(["ids": .optional(.array(of: .string("A photo's id.")))], required: []),
               example: .object([:]), availability: { _ in .unavailable(catalogFilesHelp) }
        ) { _, _ -> JSONValue in throw CatalogError.notBuilt(id: "photo.remove-from-catalog", feature: "catalog-files LC-6") },
        .typed("photo.relink", title: "Relink",
               summary: "Points a missing photo at its new file, and every missing photo from the same folder at the same name and size there.",
               kind: .edit, params: RelinkParams.self,
               schema: .object(["id": .string("The missing photo's id."), "file": .string("Its new file.")], required: ["id", "file"]),
               example: .object(["id": .string("IMG_0001"), "file": .string("/tmp/Moved/IMG_0001.jpg")]),
               availability: { _ in .unavailable(catalogFilesHelp) }
        ) { _, _ -> JSONValue in throw CatalogError.notBuilt(id: "photo.relink", feature: "catalog-files LC-6") },
    ]
}
