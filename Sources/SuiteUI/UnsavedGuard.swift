// UnsavedGuard.swift (adopt-kernel-unsaved-prompt UP-1 stubs, UP-3 bodies): the one asker every editor uses before
// unsaved work goes away. The words and answers are the kernel's `UnsavedPrompt`; the dirty rule is the app's
// `DocumentSession`. Until UP-3 the modifier returns the view unchanged and `proceed` always goes on.
import AppKit
import SwiftUI

/// What the guard reads from the app's document: its button id prefix, its name, its dirty state and its save.
public struct UnsavedHooks {
    /// The prefix of the sheet's button ids: "design" gives `design.close.save`, `design.close.dontSave`, ….
    public var idPrefix: String
    /// The document's name for the message; nil when there is nothing to ask about.
    public var documentName: @MainActor () -> String?
    /// Whether the document has edits no save has written (the app's DocumentSession).
    public var isDirty: @MainActor () -> Bool
    /// Saves the document; true only when the save landed.
    public var save: @MainActor () async -> Bool

    /// Hooks for one document window.
    public init(
        idPrefix: String, documentName: @escaping @MainActor () -> String?,
        isDirty: @escaping @MainActor () -> Bool, save: @escaping @MainActor () async -> Bool
    ) {
        self.idPrefix = idPrefix
        self.documentName = documentName
        self.isDirty = isDirty
        self.save = save
    }
}

/// Asks Save, Don't Save or Cancel before a dirty document is closed, replaced or quit.
public enum UnsavedGuard {
    /// Before Open, New or Quit replaces the document: true when it may go on.
    /// Stub (UP-1): always true; UP-3 asks in a sheet on `window` when the document is dirty.
    @MainActor public static func proceed(_ hooks: UnsavedHooks, in window: NSWindow?) async -> Bool {
        true
    }
}

extension View {
    /// Puts the guard in front of the hosting window's delegate, so close, Command-W and the close button ask.
    /// Stub (UP-1): returns the view unchanged; UP-3 installs the delegate proxy.
    public func unsavedChangesGuard(_ hooks: UnsavedHooks) -> some View {
        self
    }
}
