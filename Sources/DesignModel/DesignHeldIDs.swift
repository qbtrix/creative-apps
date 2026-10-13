// DesignHeldIDs.swift: every page and node id in the document, kept beside the
// pages so minting an id looks it up instead of walking the whole tree (#433).
// Page and node ids share one namespace, as `DesignFile.check` reads them, so a
// minted id must avoid both kinds (#303).
//
// DesignWorkspace keeps it current: an add inserts the new id, a delete drops
// its subtree's ids, and undo, redo and a gesture's rewind put back the
// snapshot's index along with its pages. Only opening a file scans the tree.
// Linux-safe.

struct DesignHeldIDs: Sendable {
    private(set) var ids: Set<String> = []
    /// How many times the whole document was scanned; tests check minting doesn't.
    private(set) var scans = 0

    /// Rebuilds the index from every page and node in `pages`.
    mutating func scan(_ pages: [DesignPage]) {
        var held = Set(pages.map(\.id))
        func collect(_ nodes: [DesignNode]) {
            for node in nodes {
                held.insert(node.id)
                collect(node.children)
            }
        }
        for page in pages { collect(page.nodes) }
        ids = held
        scans += 1
    }

    /// Takes a snapshot's ids, which match the pages it restores.
    mutating func replace(with ids: Set<String>) { self.ids = ids }

    mutating func insert(_ id: String) { ids.insert(id) }

    /// Drops `nodes` and all their descendants.
    mutating func remove(_ nodes: [DesignNode]) {
        for node in nodes {
            ids.remove(node.id)
            remove(node.children)
        }
    }

    /// Drops a page and every node on it.
    mutating func remove(_ page: DesignPage) {
        ids.remove(page.id)
        remove(page.nodes)
    }

    /// The first number past `counter` whose `prefix`N isn't held. One set lookup per step,
    /// so a long run of held ids past the cap costs one pass, not one rescan each (#304).
    func firstFree(_ prefix: String, after counter: Int) -> Int {
        var number = counter + 1
        while ids.contains("\(prefix)\(number)") { number += 1 }
        return number
    }
}

extension DesignHeldIDs: Equatable {
    /// Two indexes are equal when they hold the same ids; the scan count is bookkeeping.
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.ids == rhs.ids }
}
