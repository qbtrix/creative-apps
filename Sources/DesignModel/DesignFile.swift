// DesignFile.swift: Design's file errors and the workspace's Open and Save.
// `fileData()` writes the open document and `open(_:at:)` replaces it with a
// file's pages, both through `services.filing` (on the live services that is
// LiveFiling, the codec: sorted-key JSON, version 1, and every refusal with its
// reason). `open` remembers where the file came from (`documentURL`, which
// `didSave(to:)` moves after a save). Linux-safe.
//
// Opening is all or nothing: the filing checks the whole file first and the
// workspace is touched only by the final `load`, so a refused file leaves it
// exactly as it was. Opening clears the undo history and the selection, so Open
// only fills a workspace with nothing open (`takesOpenedFile`).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum DesignFileError: Error, Equatable, Sendable {
    /// Nothing is open to write.
    case noFile
    /// The bytes are not a Design file.
    case unreadable
    case unsupportedVersion(Int)
    case noPages
    /// A page or node id that appears more than once.
    case duplicateID(String)
    /// The id of a node holding children although its kind cannot.
    case notAContainer(String)
    /// The id of a page or node whose size or position cannot be drawn.
    case invalidNumber(String)

    /// What to tell the person, ending in a full stop.
    public var reason: String {
        switch self {
        case .noFile: "There is no file open to save."
        case .unreadable: "It is not a Design file."
        case .unsupportedVersion(let version): "It was made by a newer version of Design (file version \(version))."
        case .noPages: "It has no pages."
        case .duplicateID(let id): "It uses the id \(id) more than once."
        case .notAContainer(let id): "The layer \(id) holds other layers but isn't a frame or group."
        case .invalidNumber(let id): "The size or position of \(id) isn't valid."
        }
    }
}

extension DesignWorkspace {
    /// Whether Open may put a file in this workspace: only while it holds none. A workspace that
    /// holds a file, saved or not, is never replaced; the window opens the file in a new window.
    public var takesOpenedFile: Bool { !isOpen }

    /// The open document as file bytes, written by `services.filing`. Throws `.noFile` with nothing open.
    public func fileData() throws(DesignFileError) -> Data {
        guard isOpen else { throw .noFile }
        return try services.filing.encode(DesignDocument(pages: pages))
    }

    /// Replaces the document with the file's pages, read by `services.filing`, selects the first
    /// page and clears the undo history; `url` becomes `documentURL`. A refused file throws and
    /// changes nothing.
    public mutating func open(_ data: Data, at url: URL? = nil) throws(DesignFileError) {
        let document = try services.filing.decode(data)
        load(document.pages)
        documentURL = url
    }

    /// Records that the document was just written to `url`, so Save writes there next. Not an
    /// edit: it marks the current step as saved and ends the edit run (DesignHistory).
    public mutating func didSave(to url: URL) {
        documentURL = url
        markSaved()
    }
}
