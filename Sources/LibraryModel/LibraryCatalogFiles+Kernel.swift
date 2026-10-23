// LibraryCatalogFiles+Kernel.swift (catalog-files LC-1 specs, LC-6 bodies): Remove from Catalog and Relink as
// kernel specs, one undo step each, neither deleting a file; `file.import-folder` takes `importSchema`. Relink
// reads sizes on disk, and the catalog keeps no size, so a moved photo is found by name with the size checked
// only where the old file can still be read. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension LibraryCatalog {
    /// Why Remove from Catalog can't act.
    public static let removeHelp = "Select the photos to remove."
    /// Why Relink can't act.
    public static let relinkHelp = "No photo is missing."

    struct RemoveFromCatalogParams: Codable, Sendable { var ids: [String]? }
    struct RelinkParams: Codable, Sendable { var id: String; var file: String }

    /// `file.import-folder`'s params: the folder, and the copy choice (`copyTo` left out adds in place).
    public static let importSchema = ParamSchema.object([
        "folder": .string("The folder to import."),
        "copyTo": .optional(.string("The folder the photos are copied into; left out adds them in place.")),
        "byDate": .optional(.boolean),
    ], required: ["folder"])

    /// Points the missing photo `id` at `file`, and each other missing photo from its folder at the same name
    /// there, as one "Relink" step. Throws when `id` is not missing or `file` is not there.
    mutating func relink(_ id: String, to file: String, size: (String) -> Int?) throws {
        let missing = items.filter { $0.availability == .missing }
        guard missing.contains(where: { $0.id == id }) else {
            throw CatalogError.failed(id: "photo.relink", message: "That photo isn't missing.")
        }
        guard size(file) != nil else { throw CatalogError.failed(id: "photo.relink", message: "There's no file at \(file).") }
        let map = CatalogFileRules.relinks(missing: missing, located: (id: id, file: file), size: size)
        recordEdit("Relink", ids: Set(map.keys)) { photo in
            if let path = map[photo.id] { (photo.path, photo.availability) = (path, .available) }
        }
    }

    /// `photo.remove-from-catalog` and `photo.relink`, in `commands` and the ledger.
    public static let catalogFileSpecs: [CommandSpec<LibraryCatalog>] = [
        .typed("photo.remove-from-catalog", title: "Remove from Catalog",
               summary: "Removes the photos (the selection when ids is left out) from the catalog. Their files stay on disk.",
               kind: .edit, params: RemoveFromCatalogParams.self,
               schema: .object(["ids": .optional(.array(of: .string("A photo's id.")))], required: []),
               example: .object([:]), availability: { available($0.selection.isEmpty ? removeHelp : nil) }
        ) { c, p in
            let ids = p.ids.map(Set.init) ?? c.selection
            guard !ids.isEmpty else { throw CatalogError.unavailable(id: "photo.remove-from-catalog", why: removeHelp) }
            c.removeFromCatalog(ids)
            return JSONValue.object([:])
        },
        .typed("photo.relink", title: "Relink",
               summary: "Points a missing photo at its new file, and every missing photo from the same folder at the same name and size there.",
               kind: .edit, params: RelinkParams.self,
               schema: .object(["id": .string("The missing photo's id."), "file": .string("Its new file.")], required: ["id", "file"]),
               example: .object(["id": .string("IMG_0001"), "file": .string("/tmp/Moved/IMG_0001.jpg")]),
               availability: { available($0.items.contains { $0.availability == .missing } ? nil : relinkHelp) }
        ) { c, p in
            try c.relink(p.id, to: p.file, size: LiveImporter.size)
            return JSONValue.object([:])
        },
    ]
}
