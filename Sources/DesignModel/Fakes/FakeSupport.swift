// Fakes/FakeSupport.swift: tree helpers the fixture fakes share (the select and
// arrange fakes now, the tier-2 fakes later). Internal, never part of the API.
// They walk the whole tree once per call, however many ids, so a fake acts on layers inside frames and groups
// exactly as the journeys select them. fakeHelp and fakeChange keep the help
// law: a help is nil exactly when the write succeeds or only reports
// `.unchanged`. Linux-safe.

/// The nodes of `page` named in `ids`, in the order of `ids`; unknown ids are skipped.
func fakeFind(_ ids: [String], _ page: DesignPage) -> [DesignNode] {
    let found = fakeWalk(ids, page.nodes)
    return ids.compactMap { found[$0]?.node }
}

/// The id of the parent all of `ids` share (nil: the top level), or `.notSameParent`.
func fakeSharedParent(_ ids: [String], _ page: DesignPage) throws(DesignRefusal) -> String? {
    let found = fakeWalk(ids, page.nodes)
    let parents = Set(ids.map { found[$0].map { $0.parent ?? "" } ?? "" })
    guard parents.count == 1, let parent = parents.first else { throw .notSameParent }
    return parent.isEmpty ? nil : parent
}

/// Each of `ids` in the tree with its parent's id, in one walk however many there are (one walk per
/// id made Group of 400 frames on 20,000 layers take 38 s, #6198).
private func fakeWalk(_ ids: [String], _ nodes: [DesignNode]) -> [String: (node: DesignNode, parent: String?)] {
    let wanted = Set(ids)
    var out: [String: (node: DesignNode, parent: String?)] = [:]
    func walk(_ nodes: [DesignNode], _ parent: String?) {
        for node in nodes {
            if wanted.contains(node.id), out[node.id] == nil { out[node.id] = (node, parent) }
            if out.count == wanted.count { return }
            walk(node.children, node.id)
        }
    }
    walk(nodes, nil)
    return out
}

/// Runs `body` on the children of `parentID` (the top level when nil) in a copy of the tree.
func fakeSiblings(_ parentID: String?, _ nodes: [DesignNode], _ body: (inout [DesignNode]) -> Void) -> [DesignNode] {
    var tree = nodes
    if let parentID {
        _ = tree.update(parentID) { body(&$0.children) }
    } else {
        body(&tree)
    }
    return tree
}

/// The smallest rectangle holding every frame; nil for none (the shared `DesignRect.union`).
func fakeUnion(_ frames: [DesignRect]) -> DesignRect? {
    DesignRect.union(frames)
}

/// Changes the named layers anywhere in the tree as one edit. Nothing named: `.nothingSelected`;
/// nothing changed: `.unchanged`. With `key` the edit coalesces under `runKey(key, ids)`.
func fakeChange(_ ids: [String], _ page: DesignPage, _ name: String, key: String? = nil,
                _ body: (inout DesignNode) -> Void) throws(DesignRefusal) -> DesignEdit {
    guard !fakeFind(ids, page).isEmpty else { throw .nothingSelected }
    var nodes = page.nodes
    for id in ids { _ = nodes.update(id, body) }
    guard nodes != page.nodes else { throw .unchanged }
    return DesignEdit(name: name, nodes: nodes, selection: ids, coalescingKey: key.map { DesignEdit.runKey($0, ids) })
}

/// The help for `body` under the help law: nil when it succeeds or only reports `.unchanged`.
func fakeHelp(_ body: () throws(DesignRefusal) -> DesignEdit) -> String? {
    do { _ = try body(); return nil } catch .unchanged { return nil } catch { return error.help }
}

/// "Select a layer first." when none of `ids` is on the page, else nil.
func fakeSelectedHelp(_ ids: [String], _ page: DesignPage) -> String? {
    fakeFind(ids, page).isEmpty ? DesignRefusal.nothingSelected.help : nil
}
