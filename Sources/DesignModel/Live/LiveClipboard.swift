// Live/LiveClipboard.swift: Cut, Copy and Paste on the live services (copy-group
// C-3, #415). Copy writes a LayerPayload: version 1, the id of the first layer's
// parent, and the selected layers with their subtrees in DesignFile's node
// encoding. Paste decodes it, gives every copied node a fresh id through
// LiveDuplicating's `copySubtree` (one id-refreshing copy, never a second), and
// appends the copies to the destination: the frame the caller passes, else the
// parent the copies came from when it holds children on this page, else the top
// level. The copies move by (10, 10) only when one would land exactly on a
// sibling with the same name and frame. The app moves the bytes; Cut is the
// workspace's copy-then-delete step.
//
// Invariants:
// - Bytes that don't decode, a version other than 1 or no nodes throw
//   `.unreadable` and change nothing; `pasteHelp` says so for them and for nil.
// - No pasted id repeats one on the page or another pasted id (the mint's).
// - Each help is nil exactly when its write succeeds (the help law).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What Copy puts on the pasteboard: DesignFile's node encoding plus where the layers came from.
struct LayerPayload: Codable, Equatable {
    var version: Int
    var parentID: String?
    var nodes: [DesignNode]
}

public struct LiveClipboard: LayerClipboard {
    public init() {}

    public var pasteboardType: String { "org.creativesuite.design.layers" }

    /// "Select a layer first." when none of `ids` is on the page: exactly when `encode` throws.
    public func copyHelp(_ ids: [String], on page: DesignPage) -> String? { fakeSelectedHelp(ids, page) }

    /// The selected layers on `page`, in selection order, and the parent of the first.
    public func encode(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> Data {
        let nodes = fakeFind(ids, page)
        guard let first = nodes.first else { throw .nothingSelected }
        let payload = LayerPayload(version: 1, parentID: page.nodes.ancestors(of: first.id)?.last, nodes: nodes)
        do { return try JSONEncoder().encode(payload) } catch { throw .unreadable }
    }

    public func pasteHelp(_ data: Data?) -> String? {
        guard let data, Self.payload(data) != nil else { return DesignRefusal.unreadable.help }
        return nil
    }

    /// One "Paste" step: fresh ids, into the destination (see the file comment); the copies selected.
    public func paste(_ data: Data, into parentID: String?, on page: DesignPage,
                      mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        guard let payload = Self.payload(data) else { throw .unreadable }
        let target = [parentID, payload.parentID].lazy.compactMap { $0 }.first { Self.holds($0, page) }
        let siblings = target.flatMap { page.nodes.node($0)?.children } ?? page.nodes
        let duplicating = LiveDuplicating()
        var copies = payload.nodes.map { duplicating.copySubtree($0, mint: &mint) }
        let landsOnOne = copies.contains { copy in
            siblings.contains { $0.name == copy.name && $0.frame == copy.frame }
        }
        if landsOnOne {
            for index in copies.indices { copies[index].translate(by: DesignPoint(x: 10, y: 10)) }
        }
        let pasted = copies
        let nodes = fakeSiblings(target, page.nodes) { $0 += pasted }
        return DesignEdit(name: "Paste", nodes: nodes, selection: pasted.map(\.id))
    }

    /// Whether `id` is a layer on `page` that holds children.
    private static func holds(_ id: String, _ page: DesignPage) -> Bool {
        page.nodes.node(id)?.kind.holdsChildren == true
    }

    /// The payload in `data`; nil for bytes that don't decode, another version, or no nodes.
    static func payload(_ data: Data) -> LayerPayload? {
        guard let payload = try? JSONDecoder().decode(LayerPayload.self, from: data),
              payload.version == 1, !payload.nodes.isEmpty else { return nil }
        return payload
    }
}
