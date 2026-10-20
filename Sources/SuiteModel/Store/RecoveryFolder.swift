// RecoveryFolder.swift (autosave-history AH-1 stub, AH-7 body): the recovery files an open document's autosave
// writes, over the suite store's atomic `FileStore`. Two files per window under "Recovery/": the raw bytes in the
// app's own encoding, `<window>.<ext>`, and `<window>.json` with the name and time, written second. Until AH-7
// every call throws `RecoveryFolder.notBuilt`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One window's left-behind recovery copy: the window, the document's name, when it was written and its bytes.
public struct RecoveryItem: Hashable, Sendable {
    public var window: String, name: String?, savedAt: Double, data: Data

    public init(window: String, name: String?, savedAt: Double, data: Data) {
        (self.window, self.name, self.savedAt, self.data) = (window, name, savedAt, data)
    }
}

/// The recovery files under "Recovery/" in a store's folder.
public struct RecoveryFolder: Sendable {
    /// What every call throws until AH-7 builds the body.
    public static let notBuilt = SuiteError.notAvailable("Recovery isn't built yet (autosave-history AH-7).")

    /// The store the files live in, and the app's file extension for the raw bytes ("ora", "flare").
    let store: FileStore, ext: String

    /// Files under "Recovery/" in `store`'s folder, the raw bytes named `<window>.<ext>`.
    public init(store: FileStore, ext: String) { (self.store, self.ext) = (store, ext) }

    /// Writes `data` as `window`'s copy of the document `name`, autosaved at `at`. Stub: throws; AH-7 fills this in.
    public func write(_ data: Data, window: String, name: String?, at: Double) throws(SuiteError) { throw Self.notBuilt }
    /// Every copy left behind, newest first; a damaged pair is dropped and deleted. Stub: throws; AH-7 fills this in.
    public func leftBehind() throws(SuiteError) -> [RecoveryItem] { throw Self.notBuilt }
    /// Removes `window`'s two files; missing ones are fine. Stub: throws; AH-7 fills this in.
    public func discard(window: String) throws(SuiteError) { throw Self.notBuilt }
    /// Removes every recovery file. Stub: throws; AH-7 fills this in.
    public func discardAll() throws(SuiteError) { throw Self.notBuilt }
}
