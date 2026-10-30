// DesignRecovery+Kernel.swift: the workspace on SuiteKernel's history panel and SuiteModel's
// autosave recovery (design/autosave-history). `historyListing` is DesignHistory's kernel
// History as the panel lists it, its base "Open" for a file the window opened or saved and
// "New Design" otherwise, which was never saved and so marks no saved step; `jumpHistory(to:)` lands on that step and records nothing: it ends
// the open run, as History.jumpEndingRun does, then walks the kernel's undo and redo through
// DesignHistory's own `undo()` / `redo()`, so a jump restores each step exactly as Edit > Undo
// does (counters never go back, a New File swap brings its location back). Out of range, or
// mid-drag and while editing text where Undo is ignored, it refuses with `.unchanged`.
// `recoveryBytes()` is the document as DesignFile writes it, for SuiteUI's autosave to hand to a
// RecoveryFolder, and `recovered(from:name:)` the workspace those bytes reopen as: no location
// and a saved mark no step carries (the kernel's ids never go negative), so it is dirty and Save
// asks for a name. The name is the window's to show; the Model keeps no title. Damaged bytes
// throw DesignFile's error. `restoreRecovered(from:name:)` puts that workspace in this one,
// keeping its services, since a view never assigns the workspace (DesignRecoveryTests). No
// history logic lives here: the steps and their payloads are the kernel's. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignWorkspace: HistoryJumping {
    /// The history as the panel lists it; the state before the first step is "Open" or "New Design".
    /// A document with no location was never saved, so it lists no saved state.
    public var historyListing: HistoryListing {
        guard documentURL != nil else {
            var listing = history.kernel.listing(base: "New Design")
            listing.savedIndex = nil
            return listing
        }
        return history.kernel.listing(base: "Open")
    }

    /// Lands on step `index` of `historyListing` without recording one; refuses out of range and
    /// while Undo is ignored (mid-drag, editing text).
    public mutating func jumpHistory(to index: Int) throws {
        let listing = historyListing
        guard (0...listing.steps.count).contains(index), gesture == nil, editingTextID == nil else {
            throw DesignRefusal.unchanged
        }
        endEditRun()
        for _ in index..<max(index, listing.index) { undo() }
        for _ in listing.index..<max(listing.index, index) { redo() }
    }

    /// Opens the request span `name` (nil closes it) on the kernel history.
    public mutating func setHistoryRequest(_ name: String?) -> Bool { history.kernel.setRequest(name) }
}

extension DesignWorkspace {
    /// A saved mark no kernel step carries: its ids start at 0 and only grow.
    static let neverSavedStepID = Int.min

    /// The open document as DesignFile writes it, for the autosave. Throws with nothing open.
    public func recoveryBytes() throws -> Data {
        try fileData()
    }

    /// The workspace autosaved `data` reopens as, named `name` by the window: the same pages,
    /// no location and dirty, so Save asks where. Damaged bytes throw.
    public static func recovered(from data: Data, name: String?) throws -> DesignWorkspace {
        var workspace = DesignWorkspace()
        try workspace.open(data)
        workspace.history.kernel.savedStepID = neverSavedStepID
        return workspace
    }

    /// Puts the workspace `data` recovers as in this one, keeping this one's services.
    public mutating func restoreRecovered(from data: Data, name: String?) throws {
        var restored = try Self.recovered(from: data, name: name)
        restored.useServices(services)
        self = restored
    }
}
