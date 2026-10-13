// FlareFiles.swift: Flare's file state (docs/blueprints/flare.md, LM-1). Open
// goes through FlareCore's `FlareFormat.decode` and the workspace's `load`;
// save data comes from `FlareFormat.encode`, so save then open is
// byte-identical. Decode and encode are pure and Sendable, so the app runs
// them off the main thread (`decodeFile`, `fileData`) and hands the result to
// `finishOpen` or `didSave`. A bad file keeps the open document and leaves a
// message from section 3.3 in `loadState`. The dirty flag is set by every
// document change (`step`) and cleared by a save or a fresh load. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

extension FlareWorkspace {
    /// Most files Open Recent lists.
    public static let recentLimit = 10
    /// Seconds after the last edit when the recovery file is written.
    public static let autosaveDelay: Double = 30

    /// The alert text for a file that won't open (section 3.3). Never an enum dump.
    public static func message(for error: FormatError) -> String {
        switch error {
        case .notAFlareFile, .malformed:
            return "This file isn't a Flare animation."
        case .unsupportedVersion(let version) where version > FlareFormat.currentVersion:
            return "This file was made by a newer Flare (format \(version)). Update Flare to open it."
        case .unsupportedVersion:
            return "This file isn't a Flare animation."
        case .tooLarge:
            return "This file is larger than Flare can open (\(FlareFormat.maxFileBytes / 1_048_576) MB)."
        case .invalid(let detail):
            var detail = trimmed(detail)
            while detail.hasSuffix(".") { detail.removeLast() }
            let readable = !detail.isEmpty && !detail.contains { "(\"\\".contains($0) }
            return readable ? "This file is damaged: \(detail)." : "This file is damaged."
        }
    }

    /// Decodes a file's bytes. Pure and Sendable: run it off the main thread.
    public static func decodeFile(_ data: Data) -> Result<Document, FormatError> {
        Result { try FlareFormat.decode(data) }.mapError { $0 as? FormatError ?? .malformed("\($0)") }
    }

    /// Encodes `document` as a file's bytes. Pure and Sendable: run it off the main thread.
    public static func fileData(for document: Document) -> Result<Data, FormatError> {
        Result { try FlareFormat.encode(document) }.mapError { $0 as? FormatError ?? .invalid("\($0)") }
    }

    /// Marks an open as under way, so the window can show progress.
    public mutating func beginOpen() {
        loadState = .loading
    }

    /// Ends an open with its decode result. Success loads the document in a
    /// fresh engine, names it after `path` and puts `path` first in Open
    /// Recent. Failure keeps everything and leaves the message in `loadState`.
    public mutating func finishOpen(_ result: Result<Document, FormatError>, path: String) {
        switch result {
        case .success(let document):
            load(document)
            fileName = Self.fileName(of: path)
            noteRecent(path)
        case .failure(let error):
            loadState = .failed(Self.message(for: error))
        }
    }

    /// Opens a file's bytes on this thread, like `finishOpen(decodeFile(data))`,
    /// and rethrows a decode failure after recording it.
    public mutating func open(_ data: Data, path: String) throws(FormatError) {
        let result = Self.decodeFile(data)
        finishOpen(result, path: path)
        if case .failure(let error) = result { throw error }
    }

    /// Clears an open failure once its alert is dismissed.
    public mutating func dismissOpenError() {
        if case .failed = loadState { loadState = .idle }
    }

    /// The open document as a file's bytes; nil with no document. An encode
    /// failure is reported in `saveError`. Saving finishes with `didSave`.
    public mutating func saveData() -> Data? {
        guard let document else { return nil }
        switch Self.fileData(for: document) {
        case .success(let data):
            return data
        case .failure(let error):
            saveFailed(Self.message(for: error))
            return nil
        }
    }

    /// Records a finished write to `path`: the document is clean, named
    /// after the file, and first in Open Recent.
    public mutating func didSave(to path: String) {
        fileName = Self.fileName(of: path)
        isDirty = false
        saveError = nil
        noteRecent(path)
    }

    /// Records a failed write with the system's `reason`; the changes stay unsaved.
    public mutating func saveFailed(_ reason: String) {
        let name = fileName ?? "the animation"
        let reason = Self.trimmed(reason)
        saveError = reason.isEmpty ? "Flare couldn't save \(name)." : "Flare couldn't save \(name). \(reason)"
    }

    public mutating func dismissSaveError() {
        saveError = nil
    }

    /// Drops a file from Open Recent, for example one that no longer exists.
    public mutating func forgetRecent(_ path: String) {
        recent.removeAll { $0 == path }
    }

    /// Open Recent > Clear Menu.
    public mutating func clearRecent() {
        recent = []
    }

    /// When the recovery file is due, in the same clock as `lastEdit`
    /// (seconds); nil when there is nothing unsaved.
    public func autosaveDue(lastEdit: Double) -> Double? {
        isDirty ? lastEdit + Self.autosaveDelay : nil
    }

    private mutating func noteRecent(_ path: String) {
        recent.removeAll { $0 == path }
        recent.insert(path, at: 0)
        if recent.count > Self.recentLimit { recent.removeLast(recent.count - Self.recentLimit) }
    }

    private static func trimmed(_ text: String) -> String {
        String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    }

    private static func fileName(of path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}
