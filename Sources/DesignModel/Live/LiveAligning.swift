// Live/LiveAligning.swift: Align and Distribute for the selected layers, the
// shipping LayerAligning. One layer keeps today's rule from DesignAlign.swift:
// it lines up with its nearest enclosing frame or the page. Several layers line
// up with the union of their frames; a locked layer (or one inside a locked
// layer) counts toward that union but stays where it is. Distribute keeps the
// two outermost layers on the axis and spaces the ones between so every gap is
// equal (#714). A layer inside a hidden layer refuses both, as one-layer align
// always has.
//
// Invariants:
// - Each write is one undo step named after its command, with no coalescing
//   key, and leaves the selection as passed.
// - Help law: each help runs its write and reports the refusal, so it is nil
//   exactly when the write succeeds or only finds nothing to change; one layer
//   already at its edge reports `alreadyHelp`, as today.
// - Targets come from the bounds and each layer's own size, so a repeat
//   changes nothing.
// Linux-safe.

public struct LiveAligning: LayerAligning {
    public init() {}

    public func alignHelp(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) -> String? {
        help(already: ids.count == 1 ? edge.alreadyHelp : nil) { () throws(DesignRefusal) in try align(edge, ids, on: page) }
    }

    public func align(_ edge: DesignAlignEdge, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let selected = try layers(ids, on: page)
        let movable = selected.filter { !isLocked($0.id, on: page) }
        if movable.isEmpty, let locked = selected.first { throw .locked(locked.name) }
        let box = selected.count == 1 ? selected.first.flatMap { page.alignBounds($0.id) } : union(selected.map(\.frame))
        guard let box else { throw .nothingSelected }
        var nodes = page.nodes
        // Outer layers first, so a selected layer inside another lands on its own target.
        for node in movable.sorted(by: { depth($0.id, on: page) < depth($1.id, on: page) }) {
            _ = nodes.update(node.id) { node in
                let target = edge.origin(of: node.frame, in: box)
                if target.isFinite { node.translate(by: DesignPoint(x: target.x - node.frame.x, y: target.y - node.frame.y)) }
            }
        }
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: edge.title, nodes: nodes, selection: ids)
    }

    public func distributeHelp(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try distribute(axis, ids, on: page) }
    }

    public func distribute(_ axis: DesignDistributeAxis, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let horizontal = axis == .horizontal
        func low(_ f: DesignRect) -> Double { horizontal ? f.x : f.y }
        func size(_ f: DesignRect) -> Double { horizontal ? f.width : f.height }
        let sorted = try layers(ids, on: page).sorted { low($0.frame) < low($1.frame) }
        guard sorted.count >= 3, let first = sorted.first, let last = sorted.last else { throw .tooFewToDistribute }
        let inner = sorted.dropFirst().dropLast()
        if let locked = inner.first(where: { isLocked($0.id, on: page) }) { throw .locked(locked.name) }
        let start = low(first.frame) + size(first.frame)
        let gap = (low(last.frame) - start - inner.reduce(0) { $0 + size($1.frame) }) / Double(inner.count + 1)
        var nodes = page.nodes
        var cursor = start
        for node in inner {
            let to = cursor + gap
            _ = nodes.update(node.id) {
                $0.translate(by: horizontal ? DesignPoint(x: to - $0.frame.x, y: 0) : DesignPoint(x: 0, y: to - $0.frame.y))
            }
            cursor = to + size(node.frame)
        }
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: axis.title, nodes: nodes, selection: ids)
    }

    /// The layers `ids` name, in that order. Refuses an empty list, an id not on `page`, and a
    /// layer inside a hidden one (named by the selected layer, not the hidden one).
    private func layers(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> [DesignNode] {
        guard !ids.isEmpty else { throw .nothingSelected }
        var found: [DesignNode] = []
        for id in ids {
            guard let node = page.nodes.node(id) else { throw .unknownID(id) }
            if page.hasHiddenAncestor(id) { throw .hidden(node.name) }
            found.append(node)
        }
        return found
    }

    /// Whether `id` or a layer around it is locked.
    private func isLocked(_ id: String, on page: DesignPage) -> Bool {
        ((page.nodes.ancestors(of: id) ?? []) + [id]).contains { page.nodes.node($0)?.isLocked == true }
    }

    private func depth(_ id: String, on page: DesignPage) -> Int { page.nodes.ancestors(of: id)?.count ?? 0 }

    private func union(_ frames: [DesignRect]) -> DesignRect? {
        guard let minX = frames.map(\.x).min(), let minY = frames.map(\.y).min(),
            let maxX = frames.map(\.maxX).max(), let maxY = frames.map(\.maxY).max()
        else { return nil }
        return DesignRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The help law: nil when `write` succeeds, `already` when it finds nothing to change, else the refusal's help.
    private func help(already: String? = nil, _ write: () throws(DesignRefusal) -> DesignEdit) -> String? {
        do {
            _ = try write()
            return nil
        } catch .unchanged {
            return already
        } catch {
            return error.help
        }
    }
}
