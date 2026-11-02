// Live/LiveFiling.swift: Design's file codec, behind Open, Save and Save As on
// the live services (DesignFile calls it through `services.filing`). A file is
// JSON with sorted keys, so the same document always writes the same bytes.
//
// Version policy: the version is a function of the content. A still document
// (no keyed node, the default document time) writes `{"pages":[...],"version":1}`,
// byte for byte as before time existed. A document with keys or a set time writes
// version 2, which adds `"time"` and the nodes' `"time"` tracks. Decoding accepts
// 1 and 2 and refuses anything else with `unsupportedVersion(n)`, so a build that
// only knows 1 refuses a version 2 file rather than opening it with its keys gone.
// Recovery copies use the same codec, so they carry the same version.
//
// Decoding is all or nothing: the whole file is checked before a document is
// returned, so a refused file throws and the caller keeps what it had. A file
// is refused when it isn't JSON of this shape, names a version other than 1 or 2,
// has no page, repeats an id (page and node ids share one namespace, as
// `selectItem` looks them up together), nests children under a node that
// cannot hold them, or has a page or node whose size is under 1 point or whose
// numbers are not finite, a negative corner radius, an opacity outside 0...1, a
// negative stroke width or a text size under 1 point. A node written before the
// style fields existed opens with each at its default (DesignNode's decoder).
// Encoding runs the same check, so a file written here always opens again.
// Components and variables are not in the file until wave 2 (D2-1). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The file's JSON.
private struct DesignFileContent: Codable {
    var version: Int
    var pages: [DesignPage]
    /// Written only at version 2.
    var time: DesignDocumentTime?
}

public struct LiveFiling: DocumentFiling {
    /// The newest version this build reads and writes.
    static let fileVersion = 2

    /// 2 for a document with keys or a set document time, else 1.
    static func version(of document: DesignDocument) -> Int {
        let keyed = document.pages.contains { $0.nodes.contains { $0.isKeyed } }
        return keyed || document.time != DesignDocumentTime() ? 2 : 1
    }

    public init() {}

    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data {
        try Self.check(document.pages)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            let version = Self.version(of: document)
            return try encoder.encode(
                DesignFileContent(version: version, pages: document.pages, time: version == 2 ? document.time : nil))
        } catch {
            // Every number is finite after `check`, which is all that makes the encoder throw.
            throw .unreadable
        }
    }

    public func decode(_ data: Data) throws(DesignFileError) -> DesignDocument {
        let content: DesignFileContent
        do {
            // The version first, through the kernel's probe (`probeVersion`, DesignSession+Kernel.swift),
            // so a file from a future format reports its version and not "unreadable".
            let version = try Self.probeVersion(data)
            guard (1...Self.fileVersion).contains(version) else { throw DesignFileError.unsupportedVersion(version) }
            content = try JSONDecoder().decode(DesignFileContent.self, from: data)
        } catch let error as DesignFileError {
            throw error
        } catch {
            throw .unreadable
        }
        try Self.check(content.pages)
        return DesignDocument(pages: content.pages, time: content.time ?? DesignDocumentTime())
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
        func styled(_ node: DesignNode) -> Bool {
            let strokeWidth = node.stroke?.width ?? 0
            return (0...1).contains(node.opacity) && strokeWidth.isFinite && strokeWidth >= 0
                && node.textStyle.size.isFinite && node.textStyle.size >= 1
        }
        func checkNodes(_ nodes: [DesignNode]) throws(DesignFileError) {
            for node in nodes {
                try claim(node.id)
                guard drawable(node.frame), node.cornerRadius.isFinite, node.cornerRadius >= 0, styled(node) else {
                    throw .invalidNumber(node.id)
                }
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
