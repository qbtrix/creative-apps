// LibraryDeleteRejects+Control.swift (cull-finish DR-u): the spec Photo > Delete Rejected Photos… and its
// confirm's Move to Trash are built from (command-catalog CC-11).
import SuiteKernel

/// The Delete Rejected controls as they read their state: why trashing the rejects can't run now, nil when it can.
public struct LibraryDeleteRejectsControl: Sendable, Equatable {
    public var help: String?
    public init(help: String?) { self.help = help }
}

extension LibraryCatalog {
    /// Photo > Delete Rejected Photos… and the confirm's Move to Trash (`photo.delete-rejects`): the window asks
    /// before anything moves to the Trash, so the spec stays out of `commands` (and the ledger) like `file.share`;
    /// it is available while the control's help is nil.
    public static let deleteRejectsControlSpec: CommandSpec<LibraryDeleteRejectsControl> =
        .typed("photo.delete-rejects", title: "Delete Rejected Photos…",
               summary: "Moves the collection's rejected photos to the Trash after asking once.", kind: .edit,
               params: NoParams.self, schema: ParamSchema.none, example: .object([:]), availability: { available($0.help) }
        ) { _, _ -> JSONValue in throw CatalogError.unavailable(id: "photo.delete-rejects", why: deleteRejectsInWindow) }

    /// Why `photo.delete-rejects` doesn't run as a command.
    static let deleteRejectsInWindow = "Photo > Delete Rejected Photos… asks in the window before it moves anything to the Trash."
}
