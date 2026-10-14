// FlareFiles.swift: opening and saving .flare files (docs/blueprints/flare.md, LM-1). An open shows its progress
// state first (`beginOpen`), decodes off the main thread (`decodeFile` is pure), then lands through `load`
// (`finishOpen`); a bad file leaves the open document as it was and says why in `loadState`, with section 3.3's
// text for each FormatError. A save hands the app the file's bytes (`saveData`), and the app reports the write
// back (`didSave`, `saveFailed`). `isDirty` compares the document with the one last opened or saved, so undoing
// back to the save is clean again. The app does the file panels and the disk; the Open Recent list and the
// autosave due time follow in a later PR on #356.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

extension FormatError {
    /// The open-failure alert's text (docs/blueprints/flare.md, section 3.3).
    public var message: String {
        switch self {
        case .notAFlareFile, .malformed: "This file isn't a Flare animation."
        case .unsupportedVersion(let version):
            "This file was made by a newer Flare (format \(version)). Update Flare to open it."
        case .tooLarge: "This file is larger than Flare can open (\(FlareFormat.maxFileBytes / (1024 * 1024)) MB)."
        case .invalid(let detail): FlareWorkspace.sentence("This file is damaged", detail)
        }
    }
}

/// The bytes of a save and the document they hold, so `didSave` marks exactly that document as saved.
public struct FlareSave: Sendable, Equatable {
    public let data: Data
    let document: Document
}

extension FlareWorkspace {
    /// Unsaved changes: the document differs from the one last opened or saved.
    public var isDirty: Bool { document != savedDocument }

    /// The window title: the file's name without `.flare`, or "Untitled" before the first save.
    public var title: String {
        guard let name = fileName, !name.isEmpty else { return "Untitled" }
        return name.hasSuffix(".flare") ? String(name.dropLast(6)) : name
    }

    /// Shows the open's progress state (QB-L9) before the file is read; the open document stays as it is.
    public mutating func beginOpen() { loadState = .loading }

    /// Decodes a file's bytes; pure, so the app runs it off the main thread (QB-L12).
    public static func decodeFile(_ data: Data) -> Result<Document, FormatError> {
        do {
            return .success(try FlareFormat.decode(data))
        } catch let error as FormatError {
            return .failure(error)
        } catch {
            return .failure(.malformed("\(error)"))
        }
    }

    /// Lands a decoded file named `name`: opens it through `load`, clean and with no undo history. A failure keeps
    /// the open document, its name and its history, and puts the reason in `loadState`.
    public mutating func finishOpen(_ result: Result<Document, FormatError>, named name: String) {
        switch result {
        case .success(let document):
            load(document)
            fileName = name
        case .failure(let error):
            loadState = .failed(error.message)
        }
    }

    /// Opens a file's bytes at once, for small files and tests. Throws the FormatError after recording it like
    /// `finishOpen`.
    public mutating func open(_ data: Data, named name: String) throws(FormatError) {
        let result = Self.decodeFile(data)
        finishOpen(result, named: name)
        if case .failure(let error) = result { throw error }
    }

    /// The file's bytes for the open document; nil, with the reason in `saveError`, when there is nothing to save
    /// or the document can't be written. Saving twice with no edit between gives the same bytes.
    public mutating func saveData() -> FlareSave? {
        guard let document else {
            saveFailed("there's no animation open.")
            return nil
        }
        do {
            return FlareSave(data: try FlareFormat.encode(document), document: document)
        } catch FormatError.invalid(let detail) {
            saveFailed(detail)
        } catch FormatError.tooLarge {
            saveFailed("it's larger than a Flare file can be")
        } catch {
            saveFailed("\(error)")
        }
        return nil
    }

    /// The app wrote `save` to a file named `name`: that becomes the title, and the document is clean unless it
    /// changed during the write.
    public mutating func didSave(_ save: FlareSave, named name: String) {
        savedDocument = save.document
        fileName = name
        saveError = nil
    }

    /// The write failed for `reason`; the document and its changes stay.
    public mutating func saveFailed(_ reason: String) {
        saveError = Self.sentence("Flare couldn't save this animation", reason)
    }

    /// Clears a shown open or save failure once its alert is dismissed.
    public mutating func dismissFileError() {
        saveError = nil
        if case .failed = loadState { loadState = .idle }
    }

    /// "Lead: detail." with one final period, or "Lead." when there is no detail.
    static func sentence(_ lead: String, _ detail: String) -> String {
        var detail = Substring(detail)
        while let last = detail.last, last == "." || last.isWhitespace { detail.removeLast() }
        while let first = detail.first, first.isWhitespace { detail.removeFirst() }
        return detail.isEmpty ? "\(lead)." : "\(lead): \(detail)."
    }
}
