// LibraryCatalogFiles+Controls.swift (catalog-files LC-3): what the file controls read. Linux-safe.
import SuiteKernel

extension LibraryCatalog {
    /// Remove from Catalog and Relink as a catalog: Library's once it holds them (LC-6), else the stubs alone.
    public static let fileCommands: CommandCatalog<LibraryCatalog> = catalog.spec("photo.relink") != nil ? catalog
        : (try? CommandCatalog(app: "library", catalogFileSpecs, history: { LibraryCatalogSteps(catalog: $0) }))
            ?? .empty(app: "library")

    /// The spec of file command `id`, for a menu item or button built from it.
    public static func fileSpec(_ id: String) -> CommandSpec<LibraryCatalog>? { fileCommands.spec(id) }
    /// How many photos in the catalog have lost their file.
    public var missingCount: Int { items.reduce(0) { $0 + ($1.availability == .missing ? 1 : 0) } }
    /// The photo Locate… relinks: the first selected missing photo in the sort, else the first missing one shown.
    public var locateTarget: String? {
        let missing = Set(items.lazy.filter { $0.availability == .missing }.map(\.id))
        guard !missing.isEmpty else { return nil }
        return order.first { missing.contains($0) && selection.contains($0) } ?? order.first(where: missing.contains)
    }
    /// How many photos Remove from Catalog removes: the selection.
    public var removeCount: Int { selection.count }
    /// The confirm's title, naming the count.
    public static func removeConfirmTitle(count: Int) -> String {
        "Remove \(count) \(count == 1 ? "Photo" : "Photos") from the Catalog?"
    }
    public static let removeConfirmMessage = "Their files stay on disk. Undo puts them back with their ratings and edits."
    public static func missingBadgeTitle(count: Int) -> String {
        count == 1 ? "1 photo is missing" : "\(count) photos are missing"
    }
}

extension ImportCopyOptions {
    /// Where an import with these options puts the photos, in the import options' words.
    public var summary: String {
        guard let copyTo else { return "Adds the photos where they are." }
        let folder = copyTo.split(separator: "/").last.map(String.init) ?? copyTo
        return "Copies the photos into \(folder)" + (byDate ? ", in a folder for each day." : ".")
    }
}
