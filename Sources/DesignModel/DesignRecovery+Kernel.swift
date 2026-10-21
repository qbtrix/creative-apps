// DesignRecovery+Kernel.swift: the workspace on SuiteKernel's history panel and SuiteModel's
// autosave recovery (design/autosave-history). `historyListing` is DesignHistory's kernel
// History as the panel lists it, its base "Open" for a file the window opened or saved and
// "New Design" otherwise; `jumpHistory(to:)` will land on that step through
// History.jumpEndingRun, recording nothing. `recoveryBytes()` will be the document as
// DesignFile writes it, for SuiteUI's autosave to hand to a RecoveryFolder, and
// `recovered(from:name:)` the workspace those bytes reopen as: dirty and never saved, so Save
// asks for a name. `restoreRecovered(from:name:)` puts that workspace in this one, keeping its
// services, since a view never assigns the workspace. DA-1 declares the adapter: every write and
// both byte paths refuse with `.notBuilt("History")` until DA-5 writes their bodies
// (DesignRecoveryTests). No history logic lives here: the steps and the jump are the kernel's.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension DesignWorkspace: HistoryJumping {
    /// The history as the panel lists it; the state before the first step is "Open" or "New Design".
    public var historyListing: HistoryListing {
        history.kernel.listing(base: documentURL == nil ? "New Design" : "Open")
    }

    /// Lands on step `index` of `historyListing` without recording one. A stub until DA-5.
    public mutating func jumpHistory(to index: Int) throws {
        throw DesignRefusal.notBuilt("History")
    }
}

extension DesignWorkspace {
    /// The open document as DesignFile writes it, for the autosave. A stub until DA-5.
    public func recoveryBytes() throws -> Data {
        throw DesignRefusal.notBuilt("Recovery")
    }

    /// The workspace autosaved `data` reopens as, named `name`: dirty and never saved. A stub until DA-5.
    public static func recovered(from data: Data, name: String?) throws -> DesignWorkspace {
        throw DesignRefusal.notBuilt("Recovery")
    }

    /// Puts the workspace `data` recovers as in this one, keeping this one's services.
    public mutating func restoreRecovered(from data: Data, name: String?) throws {
        var restored = try Self.recovered(from: data, name: name)
        restored.useServices(services)
        self = restored
    }
}
