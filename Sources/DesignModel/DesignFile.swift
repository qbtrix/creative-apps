// DesignFile.swift: Design's file format and the codec between it and the
// workspace. A file is JSON, `{"pages":[...],"version":1}` with sorted keys, so
// the same document always writes the same bytes. `fileData()` writes the open
// document; `open(_:at:)` replaces it with a file's pages and remembers where it
// came from (`documentURL`, which `didSave(to:)` moves after a save). Linux-safe.
//
// Opening is all or nothing: the whole file is checked first and the workspace
// is touched only by the final `load`, so a refused file leaves it exactly as it
// was. A file is refused when it isn't JSON of this shape, names a version other
// than 1, has no page, repeats an id (page and node ids share one namespace, as
// `selectItem` looks them up together), nests children under a node that cannot
// hold them, or has a page or node whose size is under 1 point or whose numbers
// are not finite. Saving runs the same number check, so a file written here
// always opens again. Opening clears the undo history and the selection, so Open
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

/// The file's JSON.
private struct DesignFileContent: Codable {
    var version: Int
    var pages: [DesignPage]
}

/// Just the version, read first so a file from a future format reports its version
/// and not "unreadable".
private struct DesignFileHeader: Decodable {
    var version: Int
}

extension DesignWorkspace {
    private static let fileVersion = 1

    /// Whether Open may put a file in this workspace: only while it holds none. A workspace that
    /// holds a file, saved or not, is never replaced; the window opens the file in a new window.
    public var takesOpenedFile: Bool { !isOpen }

    /// The open document as file bytes. Throws `.noFile` with nothing open.
    public func fileData() throws(DesignFileError) -> Data {
        guard isOpen else { throw .noFile }
        try Self.check(pages)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            return try encoder.encode(DesignFileContent(version: Self.fileVersion, pages: pages))
        } catch {
            // Every number is finite after `check`, which is all that makes the encoder throw.
            throw .unreadable
        }
    }

    /// Replaces the document with the file's pages, selects the first page and clears the undo
    /// history; `url` becomes `documentURL`. A refused file throws and changes nothing.
    public mutating func open(_ data: Data, at url: URL? = nil) throws(DesignFileError) {
        let content: DesignFileContent
        do {
            let header = try JSONDecoder().decode(DesignFileHeader.self, from: data)
            guard header.version == Self.fileVersion else { throw DesignFileError.unsupportedVersion(header.version) }
            content = try JSONDecoder().decode(DesignFileContent.self, from: data)
        } catch let error as DesignFileError {
            throw error
        } catch {
            throw .unreadable
        }
        try Self.check(content.pages)
        load(content.pages)
        documentURL = url
    }

    /// Records that the document was just written to `url`, so Save writes there next. Not an edit.
    public mutating func didSave(to url: URL) {
        documentURL = url
    }

    /// Throws the first problem in `pages` that would make the document unusable.
    private static func check(_ pages: [DesignPage]) throws(DesignFileError) {
        guard !pages.isEmpty else { throw .noPages }
        var seen = Set<String>()
        func claim(_ id: String) throws(DesignFileError) {
            guard seen.insert(id).inserted else { throw .duplicateID(id) }
        }
        func drawable(_ rect: DesignRect) -> Bool {
            [rect.x, rect.y, rect.width, rect.height].allSatisfy(\.isFinite) && rect.width >= 1 && rect.height >= 1
        }
        func checkNodes(_ nodes: [DesignNode]) throws(DesignFileError) {
            for node in nodes {
                try claim(node.id)
                guard drawable(node.frame) else { throw .invalidNumber(node.id) }
                guard node.children.isEmpty || node.kind.holdsChildren else { throw .notAContainer(node.id) }
                try checkNodes(node.children)
            }
        }
        for page in pages {
            try claim(page.id)
            guard drawable(DesignRect(x: 0, y: 0, width: page.frameWidth, height: page.frameHeight)) else {
                throw .invalidNumber(page.id)
            }
            try checkNodes(page.nodes)
        }
    }
}
