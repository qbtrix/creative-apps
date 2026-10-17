// Live/LiveGrouping.swift: Group (Command-G) and Ungroup (Shift-Command-G) on the
// live services (copy-group C-2, #416, blueprint 5.4). Group wraps layers that
// share a parent in a new group whose frame is the union of theirs, named
// "Group N" with the lowest N no layer on the page uses, placed where the
// topmost member was. Ungroup puts each selected group's children back in its
// place, in order. Built on the tree helpers the other Live types share
// (FakeSupport); the layer tree itself is DesignNode's.
//
// Invariants:
// - Nothing moves: every leaf keeps its frame through Group and Ungroup.
// - Group keeps the members' sibling order; layers with different parents are
//   refused with `.notSameParent` and change nothing.
// - Ungroup with no group selected throws `.notAGroup(<last selected name>)`.
// - Each help is nil exactly when its write succeeds (the help law).
// Linux-safe.

public struct LiveGrouping: LayerGrouping {
    public init() {}

    public func groupHelp(_ ids: [String], on page: DesignPage) -> String? {
        fakeHelp { () throws(DesignRefusal) in
            var scratch = DesignIDMint(taken: [], after: 0)
            return try group(ids, on: page, mint: &scratch)
        }
    }

    /// One "Group" step: the new group selected, at the topmost member's place, its frame the union.
    public func group(_ ids: [String], on page: DesignPage, mint: inout DesignIDMint) throws(DesignRefusal) -> DesignEdit {
        let wanted = Set(ids)
        guard let box = fakeUnion(fakeFind(Array(wanted), page).map(\.frame)) else { throw .nothingSelected }
        let parent = try fakeSharedParent(ids.filter { page.nodes.node($0) != nil }, page)
        var made = DesignNode(id: mint.nextNodeID(), name: "Group \(freeGroupNumber(page.nodes))", kind: .group, frame: box)
        let nodes = fakeSiblings(parent, page.nodes) { siblings in
            made.children = siblings.filter { wanted.contains($0.id) }
            let top = siblings.lastIndex { wanted.contains($0.id) } ?? siblings.count
            let at = siblings[..<top].filter { !wanted.contains($0.id) }.count  // non-members under the topmost
            siblings.removeAll { wanted.contains($0.id) }
            siblings.insert(made, at: at)
        }
        return DesignEdit(name: "Group", nodes: nodes, selection: [made.id])
    }

    public func ungroupHelp(_ ids: [String], on page: DesignPage) -> String? {
        do {
            _ = try ungroup(ids, on: page)
            return nil
        } catch {
            return error.help
        }
    }

    /// One "Ungroup" step: each selected group's children take its place, in order, and are the selection.
    public func ungroup(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let found = fakeFind(ids, page)
        guard let last = found.last else { throw .nothingSelected }
        let groups = found.filter { $0.kind == .group }
        guard !groups.isEmpty else { throw .notAGroup(last.name) }
        var nodes = page.nodes
        var selection: [String] = []
        for group in groups {
            guard let current = nodes.node(group.id), let path = nodes.ancestors(of: group.id) else { continue }
            nodes = fakeSiblings(path.last, nodes) { siblings in
                guard let at = siblings.firstIndex(where: { $0.id == group.id }) else { return }
                siblings.replaceSubrange(at...at, with: current.children)
            }
            selection.removeAll { $0 == group.id }
            selection += current.children.map(\.id)
        }
        return DesignEdit(name: "Ungroup", nodes: nodes, selection: selection)
    }

    /// The lowest N ≥ 1 that no layer anywhere in `nodes` uses as "Group N".
    private func freeGroupNumber(_ nodes: [DesignNode]) -> Int {
        func names(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.name] + names($0.children) } }
        let used = Set(names(nodes))
        var n = 1
        while used.contains("Group \(n)") { n += 1 }
        return n
    }
}
