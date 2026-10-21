// FlareRecovery+Kernel.swift (adopt-kernel-autosave AK-3 stub, AK-4 body): Flare's hooks for the suite's
// `.autosaveRecovery`. The window's id names its files in `AfterGlow/Flare/Recovery/`, the encoder copies the dirty
// document and encodes it off main, and a restore opens the bytes as untitled work in one undo step
// (`RecoveryRestore`); damaged bytes throw and change nothing. `writeRecoveryOnQuit` is the quit's synchronous write of
// the same pair. `launchRecoveryFolder` runs `moveLegacyRecovery`, which moves an earlier build's copy
// (`legacyRecovery`) under the root once, never over a newer copy. Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteModel

extension FlareWorkspace {
    /// The window's id; its recovery files are `<window>.flare` and `<window>.json`. Flare has one document window.
    public var recoveryWindow: String { Self.mainWindow }

    /// The id of Flare's one document window.
    public static let mainWindow = "flare.main"

    /// Copies the document while dirty and returns the encode that runs off main; nil when clean.
    public func recoveryEncoder() -> (@Sendable () throws -> Data)? {
        guard isDirty, let document else { return nil }
        return { try FlareFormat.encode(document) }
    }

    /// The quit's last write: while dirty, the document goes to `folder` now, on the caller's thread, as the same
    /// pair the suite's autosave writes, so the next launch offers it. False when clean or the write failed.
    @discardableResult
    public func writeRecoveryOnQuit(to folder: RecoveryFolder, at time: Double) -> Bool {
        guard let encode = recoveryEncoder() else { return false }
        do {
            try folder.write(try encode(), window: recoveryWindow, name: fileName, at: time)
            return true
        } catch {
            return false
        }
    }

    /// Opens a recovered copy's bytes as unsaved, untitled work. Over an open document it is one undo step named
    /// "Restore Autosaved Copy"; with none open the restored document starts the history. Damaged bytes throw and
    /// leave the workspace as it was.
    public mutating func restoreRecovery(_ data: Data) throws {
        let recovered = try FlareFormat.decode(data)
        guard var next = engine else { return restoreRecovery(recovered) }
        try next.perform(RecoveryRestore(recovered))
        load(recovered)
        engine = next
        (savedDocument, fileName) = (nil, nil)
    }

    /// The extension of a recovery copy's raw bytes.
    public static let recoveryExtension = "flare"

    /// Where an earlier build kept Flare's one recovery copy, under the old Application Support folder.
    public static let legacyRecovery = "Flare/Recovery.flare"

    /// Where the window's copies go: `Recovery/` in Flare's folder under the suite root. Nil while the launch asks
    /// for no saved state (the journeys' `-ApplePersistenceIgnoreState`), which turns autosave off, unless it also
    /// names its own store with `-SuiteSupportDir` (the recovery journey's), as the old `-FlareRecoveryFile` did.
    public static func recoveryFolder(arguments: [String], home: String, ignoresState: Bool) -> RecoveryFolder? {
        let ownStore = SuiteLocations.supportFolder(arguments: arguments, home: home)
            != SuiteLocations.supportFolder(arguments: [], home: home)
        guard !ignoresState || ownStore else { return nil }
        let store = FileStore(folder: SuiteLocations.appFolder("Flare", arguments: arguments, home: home))
        return RecoveryFolder(store: store, ext: recoveryExtension)
    }

    /// This launch's folder (`recoveryFolder`), after an earlier build's copy moved into it. A launch that ignores
    /// state never moves it, own store or not, so a test launch never touches the person's old file.
    public static func launchRecoveryFolder(arguments: [String], home: String, ignoresState: Bool) -> RecoveryFolder? {
        guard let folder = recoveryFolder(arguments: arguments, home: home, ignoresState: ignoresState) else { return nil }
        if !ignoresState { moveLegacyRecovery(into: folder, arguments: arguments, home: home) }
        return folder
    }

    /// Moves an earlier build's `Recovery.flare` into `folder` once, as the main window's copy stamped with the old
    /// file's time; the old file goes only once the copy is written. A copy already under the root wins and both
    /// stay (`LegacySupport.plan`). Returns the step it took; a move that can't read, write or delete leaves both
    /// and returns `.keepBoth`.
    @discardableResult
    public static func moveLegacyRecovery(into folder: RecoveryFolder, arguments: [String], home: String)
        -> LegacySupport.Step {
        let files = FileManager.default
        let old = SuiteLocations.legacyFolder(legacyRecovery, home: home)
        let new = SuiteLocations.appFolder("Flare", arguments: arguments, home: home)
            + "/Recovery/\(mainWindow).\(recoveryExtension)"
        let step = LegacySupport.plan(old: old, new: new) { files.fileExists(atPath: $0) }
        guard case .move = step else { return step }
        guard let data = files.contents(atPath: old) else { return .keepBoth(old: old) }
        let modified = (try? files.attributesOfItem(atPath: old))?[.modificationDate] as? Date
        do {
            try folder.write(data, window: mainWindow, name: nil, at: modified?.timeIntervalSinceReferenceDate ?? 0)
            try files.removeItem(atPath: old)
        } catch {
            return .keepBoth(old: old)
        }
        return step
    }
}

/// The one step a restore over an open document records: it swaps in the recovered document, and its undo puts
/// back the one it replaced.
struct RecoveryRestore: Command {
    static let id = "flare.recovery.restore"
    var label: String { "Restore Autosaved Copy" }
    /// The recovered document `execute` leaves.
    let recovered: Document
    /// The document `execute` replaced, for `undo`; nil until it ran.
    private var replaced: Document?
    private enum CodingKeys: String, CodingKey { case recovered }

    init(_ recovered: Document) { self.recovered = recovered }

    mutating func execute(_ document: inout Document) throws {
        replaced = document
        document = recovered
    }

    func undo(_ document: inout Document) throws {
        guard let replaced else { throw CommandError.notExecuted }
        document = replaced
    }
}
