// HaloFiles.swift: the project's file state (#209). The bytes a save writes,
// an open from `beginOpen` to `finishOpen` (which replaces the document and
// clears history, or leaves the project as it was), what a save or a failed
// save leaves, the window title, subtitle and save status, and where Save
// writes (`saveTarget`, HF-9). The only writer of `file`, besides `edit`, undo
// and redo marking it unsaved. The status and subtitle read through the
// kernel's session and the version through its probe (HaloFiles+Kernel.swift).
// The file being opened waits in `file.pending` until `finishOpen`. Open
// Recent is the suite's one list (HaloFileFlow+Kernel.swift); Halo keeps none.
// Linux-safe: no UI imports.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Where Save or Save As… goes: straight to a file, or to the save panel.
public enum HaloSaveTarget: Equatable, Sendable {
    case write(path: String)
    case ask
}

extension HaloProject {
    /// The project file's bytes, as Save writes them.
    public func fileData() throws -> Data {
        try services.files.encode(document)
    }

    /// Starts opening the file `name` at `path`; the window shows its progress
    /// until `finishOpen`.
    public mutating func beginOpen(name: String, path: String) {
        file.pending = HaloFileRef(name: name, path: path)
        file.opening = true
        file.error = nil
    }

    /// Ends the open `beginOpen` started. A decoded document replaces this one
    /// with no undo steps and nothing unsaved; an error keeps the project as it
    /// was and sets its message.
    public mutating func finishOpen(_ result: Result<HaloDocumentState, HaloFileError>) {
        guard file.opening, let pending = file.pending else { return }
        file.opening = false
        file.pending = nil
        switch result {
        case .success(let state):
            restore(state)
            history = HaloHistory()
            file.name = pending.name
            file.path = pending.path
            file.unsaved = false
            file.error = nil
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
        sessionDidSave()
    }

    /// The save failed with `message`: the project reads "Not saved" until a
    /// save succeeds or a file opens, even with no edit since the last save.
    public mutating func didFailSave(_ message: String) {
        file.error = message
        file.unsaved = true
    }

    /// "Halo" with no composition, "Untitled Project" before a save or open,
    /// then the file's name.
    public var windowTitle: String {
        file.name ?? (compositions.isEmpty ? "Halo" : "Untitled Project")
    }

    /// "Untitled", "Saved", "Edited", or "Not saved" after a failed save.
    public var saveStatus: String {
        Self.words(for: session)
    }

    /// The title bar's subtitle: "Edited" or "Not saved" while the work
    /// isn't on disk; nil when there is nothing to warn about.
    public var windowSubtitle: String? {
        session.isDirty ? saveStatus : nil
    }

    /// A launch path (`-HaloSaveTo`) always wins; Save As… asks; Save writes
    /// the file the project was opened from or last saved to, else asks.
    public func saveTarget(launchPath: String?, saveAs: Bool) -> HaloSaveTarget {
        if let launchPath { return .write(path: launchPath) }
        if !saveAs, let path = file.path { return .write(path: path) }
        return .ask
    }

    /// The path's last component without ".halo": "/t/Spot.halo" is "Spot".
    public static func fileName(fromPath path: String) -> String {
        let last = path.split(separator: "/").last.map(String.init) ?? path
        let suffix = ".halo"
        guard last.count > suffix.count, last.lowercased().hasSuffix(suffix) else { return last }
        return String(last.dropLast(suffix.count))
    }
}
