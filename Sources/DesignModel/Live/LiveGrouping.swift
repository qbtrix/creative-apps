// Live/LiveGrouping.swift: Group (Command-G) and Ungroup (Shift-Command-G) on the
// live services (copy-group C-2, #416, blueprint 5.4). Group wraps layers that
// share a parent in a new group whose frame is the union of theirs, named
// "Group N" with the lowest N no layer on the page uses, placed where the
// topmost member was. Ungroup puts each selected group's children back in its
// place, in order. Group edits the shared parent's child list in one pass, so it
// costs one walk however many layers; Ungroup is an adapter over SuiteKernel's
// LayerTree (DesignNode+Kernel).
//
// Invariants:
// - Nothing moves: every leaf keeps its frame through Group and Ungroup.
// - Group keeps the members' sibling order; layers with different parents are
//   refused with `.notSameParent` and change nothing.
// - Ungroup with no group selected throws `.notAGroup(<last selected name>)`.
// - Each help is nil exactly when its write succeeds (the help law).
// Linux-safe.

import SuiteKernel

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
        guard let box = fakeUnion(fakeFind(Array(Set(ids)), page).map(\.frame)) else { throw .nothingSelected }
        let present = fakeFind(ids, page).map(\.id)
        let parent = try fakeSharedParent(present, page)
        var made = DesignNode(id: mint.nextNodeID(), name: "Group \(freeGroupNumber(page.nodes))", kind: .group, frame: box)
        // One sibling list, edited once: the kernel's group walks the tree per id (38 s on 20,000, #6198).
        let picked = Set(present)
        let nodes = fakeSiblings(parent, page.nodes) { kids in
            guard let front = kids.lastIndex(where: { picked.contains($0.id) }) else { return }
            let at = kids[..<front].filter { !picked.contains($0.id) }.count
            made.children = kids.filter { picked.contains($0.id) }
            kids.removeAll { picked.contains($0.id) }
            kids.insert(made, at: at)
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
        var tree = page.nodes.layerTree
        var selection: [String] = []
        for group in groups {
            guard let children = tree.node(group.id)?.children.map(\.id) else { continue }
            do throws(TreeRefusal) {
                try tree.ungroup(group.id)
            } catch {
                continue
            }
            selection.removeAll { $0 == group.id }
            selection += children
        }
        return DesignEdit(name: "Ungroup", nodes: tree.designNodes, selection: selection)
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
