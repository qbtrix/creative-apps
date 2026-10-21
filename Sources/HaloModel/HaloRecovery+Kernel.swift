// HaloRecovery+Kernel.swift (autosave-history HA-1 stubs, HA-5 bodies): Halo's
// adapter onto the kernel's History panel and SuiteUI's autosave (packet
// docs/blueprints/halo/features/autosave-history.md). The listing is the
// kernel `History`'s own (`History.listing`), its base "Open" once the project
// has a file and "New Project" before; the recovery bytes are HaloFiles' own
// encoding, the bytes Save writes. HA-5 fills the jump (the kernel's
// `jumpEndingRun`, recording no step) and the recovered project (dirty, never
// saved); until then both throw HaloNotBuilt, so the panel and the autosave
// hooks sit on the window without acting. No history logic lives here.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// A part of the recovery adapter HA-5 builds; it says so instead of acting.
public struct HaloNotBuilt: Error, Sendable, Equatable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

extension HaloProject: HistoryJumping {
    /// The project's steps as the History panel lists them, from the kernel history.
    public var historyListing: HistoryListing {
        history.kernel.listing(base: file.path == nil ? "New Project" : "Open")
    }

    /// Undoes or redoes until `index` steps are applied, recording none. Stub: throws until HA-5.
    public mutating func jumpHistory(to index: Int) throws {
        throw HaloNotBuilt("Jumping to a step arrives with HA-5.")
    }
}

extension HaloProject {
    /// The project as HaloFiles writes it, for the recovery copy.
    public func recoveryBytes() throws -> Data {
        try fileData()
    }

    /// The project in a recovery copy's bytes, marked edited and never saved, named `name`.
    /// Stub: throws until HA-5.
    public static func recovered(from data: Data, name: String?) throws -> HaloProject {
        throw HaloNotBuilt("Restoring a recovered copy arrives with HA-5.")
    }
}
