// RecoveryFolder.swift (autosave-history AH-1 contract, AH-7 body): the recovery files an open document's autosave
// writes, over the suite store's atomic `FileStore`. Two files per window under "Recovery/": the raw bytes in the
// app's own encoding, `<window>.<ext>`, and `<window>.json` with the name and time, written second. A pair missing
// either file, or whose JSON won't decode, is dropped and deleted when the copies are listed.
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
    /// The store the files live in, and the app's file extension for the raw bytes ("ora", "flare").
    let store: FileStore, ext: String

    /// Files under "Recovery/" in `store`'s folder, the raw bytes named `<window>.<ext>`.
    public init(store: FileStore, ext: String) { (self.store, self.ext) = (store, ext) }

    /// What a window's JSON file holds beside its raw bytes.
    private struct Meta: Codable { var name: String?, savedAt: Double }

    /// Writes `data` as `window`'s copy of the document `name`, autosaved at `at`: the bytes first, then the JSON,
    /// so a copy cut off half-way has no JSON and is dropped.
    public func write(_ data: Data, window: String, name: String?, at: Double) throws(SuiteError) {
        try store.writeData(raw(window), data)
        let meta: Data
        do { meta = try JSONEncoder().encode(Meta(name: name, savedAt: at)) } catch { throw .ioFailed(Self.subject) }
        try store.writeData(json(window), meta)
    }

    /// Every copy left behind, newest first; a pair whose JSON or bytes are missing or damaged is dropped and deleted.
    public func leftBehind() throws(SuiteError) -> [RecoveryItem] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
        var items: [RecoveryItem] = []
        for window in Set(names.compactMap(window(of:))).sorted() {
            guard let data = try store.readData(raw(window)), let metaData = try store.readData(json(window)),
                  let meta = try? JSONDecoder().decode(Meta.self, from: metaData), meta.savedAt.isFinite else {
                try discard(window: window)
                continue
            }
            items.append(RecoveryItem(window: window, name: meta.name, savedAt: meta.savedAt, data: data))
        }
        return items.sorted { $0.savedAt != $1.savedAt ? $0.savedAt > $1.savedAt : $0.window < $1.window }
    }

    /// Removes `window`'s two files and their locks; missing ones are fine.
    public func discard(window: String) throws(SuiteError) {
        for name in [raw(window), json(window)] {
            try remove(path(name))
            try remove(path(name) + ".lock")
        }
    }

    /// Removes every recovery file.
    public func discardAll() throws(SuiteError) { try remove(directory) }

    // MARK: Files

    /// What an error about these files names, in the words the user sees.
    static let subject = "a recovery copy"
    private var directory: String { path("Recovery") }
    private func raw(_ window: String) -> String { "Recovery/\(window).\(ext)" }
    private func json(_ window: String) -> String { "Recovery/\(window).json" }
    private func path(_ name: String) -> String { store.folder.hasSuffix("/") ? store.folder + name : store.folder + "/" + name }

    /// The window a file in "Recovery/" belongs to; nil for a lock, a temporary file or anything else.
    private func window(of file: String) -> String? {
        guard !file.hasPrefix(".") else { return nil }
        for suffix in [".json", "." + ext] where file.hasSuffix(suffix) && file.count > suffix.count {
            return String(file.dropLast(suffix.count))
        }
        return nil
    }

    /// Deletes the file or folder at `path`; a missing one is fine.
    private func remove(_ path: String) throws(SuiteError) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        guard (try? FileManager.default.removeItem(atPath: path)) != nil else { throw .ioFailed(Self.subject) }
    }
}
