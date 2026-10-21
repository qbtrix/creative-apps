// FlareRecovery+Kernel.swift (adopt-kernel-autosave AK-3 stub, AK-4 body): Flare's hooks for the suite's
// `.autosaveRecovery`. The window's id names its files in `AfterGlow/Flare/Recovery/`, the encoder copies the dirty
// document and encodes it off main with the save path's encoder, and a restore opens the bytes as unsaved work.
// `legacyRecovery` is where an earlier build kept its one copy, moved once under the root. Until AK-4 the window
// id is empty, there is no encoder and a restore throws `recoveryNotBuilt`, so nothing is written or replaced.
// Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension FlareWorkspace {
    /// The window's id; its recovery files are `<window>.flare` and `<window>.json`.
    public var recoveryWindow: String { "" }

    /// Copies the document while dirty and returns the encode that runs off main; nil when clean.
    public func recoveryEncoder() -> (@Sendable () throws -> Data)? { nil }

    /// Opens a recovered copy's bytes as unsaved work.
    public mutating func restoreRecovery(_ data: Data) throws {
        throw Self.recoveryNotBuilt
    }

    /// The extension of a recovery copy's raw bytes.
    public static let recoveryExtension = "flare"

    /// Where an earlier build kept Flare's one recovery copy, under the old Application Support folder.
    public static let legacyRecovery = "Flare/Recovery.flare"

    /// What a restore throws until AK-4 builds it.
    static let recoveryNotBuilt = NotBuilt(reason: "Recovery on the suite's autosave waits on adopt-kernel-autosave AK-4.")
}
