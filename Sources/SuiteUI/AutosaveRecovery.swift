// AutosaveRecovery.swift (autosave-history AH-2 stub, AH-8 body): the `.autosaveRecovery` modifier every app puts
// on its document window (packet docs/blueprints/suiteui/features/autosave-history.md). AH-8 makes it tick once a
// second while the document is dirty, take a ticket from the kernel's `AutosaveSchedule`, copy the document on main
// through `encoder`, encode and write it to the `RecoveryFolder` off main, and on appear offer the newest copy left
// behind as a `RecoveryOffer` alert (Restore hands its bytes to `restore`; Discard removes them). Until then the
// modifier returns the view unchanged: it never writes and never offers.
import SuiteModel
import SwiftUI

/// What the modifier reads from the app's document: its window, name, dirty state, bytes and how to restore them.
public struct AutosaveHooks {
    /// The window's id; its recovery files are named after it.
    public var window: String
    /// The document's name, nil while it is untitled.
    public var documentName: @MainActor () -> String?
    /// Whether the document has edits no save has written.
    public var isDirty: @MainActor () -> Bool
    /// Copies the document's value on main and returns the encode that runs off it; nil when there is nothing to write.
    public var encoder: @MainActor () -> (@Sendable () throws -> Data)?
    /// Opens a recovered copy's bytes in the window.
    public var restore: @MainActor (Data) async throws -> Void

    public init(
        window: String, documentName: @escaping @MainActor () -> String?, isDirty: @escaping @MainActor () -> Bool,
        encoder: @escaping @MainActor () -> (@Sendable () throws -> Data)?,
        restore: @escaping @MainActor (Data) async throws -> Void
    ) {
        self.window = window
        self.documentName = documentName
        self.isDirty = isDirty
        self.encoder = encoder
        self.restore = restore
    }
}

extension View {
    /// Autosaves the document `hooks` reads to `folder` `delay` seconds after an edit and offers a copy left behind
    /// at launch. `edits` changes on every edit (the history's current step id). `folder` nil turns autosave off
    /// (the journeys' `-ApplePersistenceIgnoreState` launch). Stub: returns the view unchanged; AH-8 fills this in.
    public func autosaveRecovery(_ hooks: AutosaveHooks, folder: RecoveryFolder?, delay: Double, edits: Int) -> some View {
        self
    }
}
