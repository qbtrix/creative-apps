// Live/LiveFiling.swift: Design's file codec, behind Open, Save and Save As on
// the live services (DesignFile calls it through `services.filing`). A file is
// JSON, `{"pages":[...],"version":1}` with sorted keys, so the same document
// always writes the same bytes.
//
// Decoding is all or nothing: the whole file is checked before a document is
// returned, so a refused file throws and the caller keeps what it had. A file
// is refused when it isn't JSON of this shape, names a version other than 1,
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
}

public struct LiveFiling: DocumentFiling {
    static let fileVersion = 1

    public init() {}

    public func encode(_ document: DesignDocument) throws(DesignFileError) -> Data {
        try Self.check(document.pages)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            return try encoder.encode(DesignFileContent(version: Self.fileVersion, pages: document.pages))
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
            guard version == Self.fileVersion else { throw DesignFileError.unsupportedVersion(version) }
            content = try JSONDecoder().decode(DesignFileContent.self, from: data)
        } catch let error as DesignFileError {
            throw error
        } catch {
            throw .unreadable
        }
        try Self.check(content.pages)
        return DesignDocument(pages: content.pages)
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
