// LibraryBackupMenuState.swift (catalog-backup BK-u): File > Restore Catalog Backup… and the Restore sheet's
// buttons as command specs over one small target, so the menu item, Restore… and the confirmation's Restore are
// built from a spec (command-catalog CC-11) and each says why it can't run. `restoreWhy` is the window's
// `catalog.restore-backup` reason; the sheet adds its own: no restore action, no backup chosen. The specs never
// run in a catalog: the menu and the sheet perform their own actions. Linux-safe.
import SuiteKernel

/// Whether a Library window is focused, why restore can't run, and the sheet's selection.
public struct LibraryBackupMenuState: Sendable, Equatable {
    public var hasWindow: Bool
    public var restoreWhy: String?
    public var selected: String?
    public var canRestore: Bool

    public init(hasWindow: Bool = false, restoreWhy: String? = nil, selected: String? = nil, canRestore: Bool = true) {
        (self.hasWindow, self.restoreWhy, self.selected, self.canRestore) = (hasWindow, restoreWhy, selected, canRestore)
    }

    /// Why File > Restore Catalog Backup… can't open the sheet, nil when it can.
    public var openWhy: String? { hasWindow ? restoreWhy : "Open the Library window first." }

    /// Why the sheet's Restore can't run: the command's reason first, then no action, then no selection; nil when it can.
    public var sheetWhy: String? {
        if let restoreWhy { return restoreWhy }
        if !canRestore { return "Restore isn't available right now." }
        return selected == nil ? "Choose a backup to restore." : nil
    }

    /// File > Restore Catalog Backup….
    public static let open = spec("backup.open", title: "Restore Catalog Backup…",
                                  summary: "Lists the catalog's backups to restore one.") { $0.openWhy }

    /// The sheet's Restore… and the confirmation's Restore.
    public static let restore = spec("backup.restore", title: "Restore…", summary: "Restore the selected backup.") { $0.sheetWhy }

    static func spec(_ id: String, title: String, summary: String,
                     why: @escaping @Sendable (Self) -> String?) -> CommandSpec<Self> {
        .typed(id, title: title, summary: summary, kind: .view, params: JSONValue.self, example: .object([:]),
               availability: { why($0).map(Availability.unavailable) ?? .available }) { _, _ in JSONValue.object([:]) }
    }
}
