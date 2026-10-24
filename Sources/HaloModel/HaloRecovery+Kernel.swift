// HaloRecovery+Kernel.swift (autosave-history HA-1, HA-5): Halo's adapter onto
// the kernel's History panel and SuiteUI's autosave (packet
// docs/blueprints/halo/features/autosave-history.md). The listing is the
// kernel `History`'s own (`History.listing`), its base "Open" once the project
// has a file and "New Project" before. The jump is the kernel's
// `jumpEndingRun`, handing each step the document it leaves and landing on the
// one it reaches, so it records no step; the file reads dirty unless it lands
// on the saved step. The recovery bytes are HaloFiles' own encoding, the bytes
// Save writes, and a recovered project decodes them through the same
// `ProjectFiles.decode` Open uses (damaged bytes throw its error), then reads
// edited, with no path and no steps; `restoreRecovered` does that in the open
// window's project, keeping its services and file flow (HA-7b). No history
// logic lives here.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension HaloHistory {
    /// The kernel's `jumpEndingRun` from `current` to `index` applied steps:
    /// each step keeps the document it leaves; the one landed on is returned.
    mutating func jump(to index: Int, from current: HaloDocumentState) -> HaloDocumentState {
        var landed = current
        kernel.jumpEndingRun(to: index) { target in
            defer { landed = target }
            return landed
        }
        runKey = nil
        return landed
    }
}

extension HaloProject: HistoryJumping {
    /// The project's steps as the History panel lists them, from the kernel history.
    public var historyListing: HistoryListing {
        history.kernel.listing(base: file.path == nil ? "New Project" : "Open")
    }

    /// Undoes or redoes until `index` steps are applied, recording none.
    public mutating func jumpHistory(to index: Int) throws {
        restore(history.jump(to: index, from: document))
        file.unsaved = history.isDirty
    }
}

extension HaloProject {
    /// The project as HaloFiles writes it, for the recovery copy.
    public func recoveryBytes() throws -> Data {
        try fileData()
    }

    /// The project in a recovery copy's bytes, on the live services, marked
    /// edited and never saved, named `name`. Damaged bytes throw Open's error.
    public static func recovered(from data: Data, name: String?) throws -> HaloProject {
        var project = HaloProject(services: .live)
        try project.restoreRecovered(from: data, name: name)
        return project
    }

    /// Puts a recovery copy's project in place of this one, as `recovered`
    /// builds it, on this project's services and keeping its file flow.
    /// Damaged bytes throw Open's error and leave the project as it was.
    public mutating func restoreRecovered(from data: Data, name: String?) throws {
        let state = try services.files.decode(data)
        restore(state)
        history = HaloHistory()
        file.name = name
        file.path = nil
        file.unsaved = true
    }
}
