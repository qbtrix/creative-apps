// HaloFiles.swift: the project's file state (#209). The bytes a save writes,
// an open from `beginOpen` to `finishOpen` (which replaces the document and
// clears history, or leaves the project as it was), what a save or a failed
// save leaves, the recent list (newest first, 10 at most, no repeated path),
// and the window title and save status. The only writer of `file`, besides
// `edit` marking it unsaved.
// W0's `HaloFileState.opening` is a Bool, so the file being opened rides at
// the head of `file.recent` until `finishOpen`; `recent` hides it.
// Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension HaloProject {
    /// How many projects Open Recent lists.
    public static let recentLimit = 10

    /// The project file's bytes, as Save writes them.
    public func fileData() throws -> Data {
        try services.files.encode(document)
    }

    /// Starts opening the file `name` at `path`; the window shows its progress
    /// until `finishOpen`.
    public mutating func beginOpen(name: String, path: String) {
        let pending = HaloRecentFile(name: name, path: path)
        file.recent = file.opening ? [pending] + file.recent.dropFirst() : [pending] + file.recent
        file.opening = true
        file.error = nil
    }

    /// Ends the open `beginOpen` started. A decoded document replaces this one
    /// with no undo steps and nothing unsaved, and the file goes first in the
    /// recent list; an error keeps the project as it was and sets its message.
    public mutating func finishOpen(_ result: Result<HaloDocumentState, HaloFileError>) {
        guard file.opening, let pending = file.recent.first else { return }
        file.opening = false
        file.recent.removeFirst()
        switch result {
        case .success(let state):
            restore(state)
            history = HaloHistory()
            file.name = pending.name
            file.path = pending.path
            file.unsaved = false
            file.error = nil
            pushRecent(pending)
        case .failure(let error):
            file.error = error.message
        }
    }

    /// The project was written to `path` as `name`.
    public mutating func didSave(name: String, path: String) {
        file.name = name
        file.path = path
        file.unsaved = false
        file.error = nil
        pushRecent(HaloRecentFile(name: name, path: path))
    }

    /// The save failed with `message`; the edits stay unsaved.
    public mutating func didFailSave(_ message: String) {
        file.error = message
    }

    /// File > Open Recent: newest first, 10 at most.
    public var recent: [HaloRecentFile] {
        Array(file.opening ? file.recent.dropFirst() : file.recent[...])
    }

    /// Sets the recent list (from the app's saved defaults), keeping the
    /// first of any repeated path and 10 at most.
    public mutating func setRecent(_ files: [HaloRecentFile]) {
        var seen = Set<String>()
        let kept = Array(files.filter { seen.insert($0.path).inserted }.prefix(Self.recentLimit))
        file.recent = file.opening ? Array(file.recent.prefix(1)) + kept : kept
    }

    /// "Halo" with no composition, "Untitled Project" before a save or open,
    /// then the file's name.
    public var windowTitle: String {
        file.name ?? (compositions.isEmpty ? "Halo" : "Untitled Project")
    }

    /// "Untitled", "Saved", "Edited", or "Not saved" after a failed save.
    public var saveStatus: String {
        if file.unsaved { return file.error != nil ? "Not saved" : "Edited" }
        return file.path == nil ? "Untitled" : "Saved"
    }

    /// Puts `entry` first, drops its path from further down, keeps 10.
    private mutating func pushRecent(_ entry: HaloRecentFile) {
        let rest = recent.filter { $0.path != entry.path }
        let list = Array(([entry] + rest).prefix(Self.recentLimit))
        file.recent = file.opening ? Array(file.recent.prefix(1)) + list : list
    }
}
