// Fakes/FakeSupport.swift: tree helpers the fixture fakes share (the select and
// arrange fakes now, the tier-2 fakes later). Internal, never part of the API.
// They walk the whole tree, so a fake acts on layers inside frames and groups
// exactly as the journeys select them. fakeHelp and fakeChange keep the help
// law: a help is nil exactly when the write succeeds or only reports
// `.unchanged`. Linux-safe.

/// The nodes of `page` named in `ids`, in the order of `ids`; unknown ids are skipped.
func fakeFind(_ ids: [String], _ page: DesignPage) -> [DesignNode] {
    ids.compactMap { page.nodes.node($0) }
}

/// The id of the parent all of `ids` share (nil: the top level), or `.notSameParent`.
func fakeSharedParent(_ ids: [String], _ page: DesignPage) throws(DesignRefusal) -> String? {
    let parents = Set(ids.map { page.nodes.ancestors(of: $0)?.last ?? "" })
    guard parents.count == 1, let parent = parents.first else { throw .notSameParent }
    return parent.isEmpty ? nil : parent
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

/// The smallest rectangle holding every frame; nil for none.
func fakeUnion(_ frames: [DesignRect]) -> DesignRect? {
    guard let first = frames.first else { return nil }
    return frames.dropFirst().reduce(first) { box, f in
        let (x, y) = (Swift.min(box.x, f.x), Swift.min(box.y, f.y))
        return DesignRect(x: x, y: y, width: Swift.max(box.maxX, f.maxX) - x, height: Swift.max(box.maxY, f.maxY) - y)
    }
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
