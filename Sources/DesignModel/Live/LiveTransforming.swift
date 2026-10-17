// Live/LiveTransforming.swift: Move, Resize, Nudge and Delete for one or more
// selected layers, the shipping SelectionTransforming. Each layer moves with its
// subtree. Resize treats the selection as one box (the union of the selected
// frames): the box takes the handle's drag with Shift and Option as a single
// layer does today, and every layer in it, children included, keeps its place
// and share of the box, at least 1 pt wide and high. The canvas still resizes a
// lone selected layer through `resizeNode`, which leaves children where they are.
//
// Invariants:
// - A selection holding a layer that is locked, or hidden, itself or by a layer
//   around it refuses every write, named by the selected layer, before anything
//   moves. The help is that refusal's help, nil exactly when the writes can run.
// - A selected layer inside another selected layer moves only with that one, so
//   nothing is ever moved twice.
// - Move, Resize and Nudge coalesce on `runKey(base, ids)`; Delete is one step.
//   A write that changes nothing throws `.unchanged`.
// - A box of no width or height never divides: that axis maps onto the new box.
// - `DesignRect.union` is the one selection-bounds union: Align, Group and the
//   fakes measure a selection with it too.
// Linux-safe.

public struct LiveTransforming: SelectionTransforming {
    public init() {}

    public func transformHelp(_ ids: [String], on page: DesignPage) -> String? {
        do {
            _ = try targets(ids, on: page)
            return nil
        } catch {
            return error.help
        }
    }

    public func move(_ ids: [String], by delta: DesignPoint, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let roots = try targets(ids, on: page)
        var nodes = page.nodes
        if delta.isFinite {
            for root in roots { _ = nodes.update(root.id) { $0.translate(by: delta) } }
        }
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: "Move", nodes: nodes, selection: ids, coalescingKey: DesignEdit.runKey("move", ids))
    }

    public func resize(_ ids: [String], handle: DesignHandle, by delta: DesignPoint, modifiers: DesignModifiers,
                       on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let roots = try targets(ids, on: page)
        guard let box = DesignRect.union(ids.compactMap { page.nodes.node($0)?.frame }) else { throw .nothingSelected }
        let new = box.resized(handle, by: delta, keepAspect: modifiers.contains(.shift), fromCenter: modifiers.contains(.option))
        var nodes = page.nodes
        for root in roots { _ = nodes.update(root.id) { $0 = scaled($0, from: box, to: new) } }
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: "Resize", nodes: nodes, selection: ids, coalescingKey: DesignEdit.runKey("resize", ids))
    }

    public func nudge(_ ids: [String], _ direction: DesignDirection, large: Bool, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let step = large ? 10.0 : 1.0
        let delta = switch direction {
        case .up: DesignPoint(x: 0, y: -step)
        case .down: DesignPoint(x: 0, y: step)
        case .left: DesignPoint(x: -step, y: 0)
        case .right: DesignPoint(x: step, y: 0)
        }
        var edit = try move(ids, by: delta, on: page)
        (edit.name, edit.coalescingKey) = ("Nudge", DesignEdit.runKey("nudge", ids))
        return edit
    }

    public func delete(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        let roots = try targets(ids, on: page)
        var nodes = page.nodes
        for root in roots { _ = nodes.remove(root.id) }
        let name = roots.count == 1 ? roots.first.map { "Delete \($0.kind.defaultName)" } : nil
        return DesignEdit(name: name ?? "Delete", nodes: nodes, selection: [])
    }

    /// The selected layers to change, each once, in `ids` order, leaving out one inside another
    /// selected layer (it goes with that one's subtree). Refuses an empty list, an id not on `page`,
    /// then the first layer locked in the tree, then the first hidden in the tree.
    private func targets(_ ids: [String], on page: DesignPage) throws(DesignRefusal) -> [DesignNode] {
        guard !ids.isEmpty else { throw .nothingSelected }
        var nodes: [DesignNode] = []
        for id in ids {
            guard let node = page.nodes.node(id) else { throw .unknownID(id) }
            nodes.append(node)
        }
        if let node = nodes.first(where: { inTree($0.id, on: page) { $0.isLocked } }) { throw .locked(node.name) }
        if let node = nodes.first(where: { inTree($0.id, on: page) { $0.isHidden } }) { throw .hidden(node.name) }
        let selected = Set(ids)
        var seen = Set<String>()
        return nodes.filter { node in
            seen.insert(node.id).inserted && !(page.nodes.ancestors(of: node.id) ?? []).contains(where: selected.contains)
        }
    }

    /// Whether `id` or a layer around it passes `test`.
    private func inTree(_ id: String, on page: DesignPage, _ test: (DesignNode) -> Bool) -> Bool {
        ((page.nodes.ancestors(of: id) ?? []) + [id]).contains { page.nodes.node($0).map(test) == true }
    }

    /// `node` and its subtree with each frame keeping its place and share of `box` inside `new`.
    private func scaled(_ node: DesignNode, from box: DesignRect, to new: DesignRect) -> DesignNode {
        // One axis: a box of no length maps everything onto the new box's start and length.
        func place(_ value: Double, _ start: Double, _ length: Double, _ newStart: Double, _ newLength: Double) -> Double {
            length > 0 ? newStart + (value - start) * newLength / length : newStart
        }
        func size(_ value: Double, _ length: Double, _ newLength: Double) -> Double {
            Swift.max(length > 0 ? value * newLength / length : newLength, 1)
        }
        var node = node
        let frame = node.frame
        node.frame = DesignRect(
            x: place(frame.x, box.x, box.width, new.x, new.width), y: place(frame.y, box.y, box.height, new.y, new.height),
            width: size(frame.width, box.width, new.width), height: size(frame.height, box.height, new.height))
        node.children = node.children.map { scaled($0, from: box, to: new) }
        return node
    }
}

extension DesignRect {
    /// The smallest rectangle holding every frame; nil for none. The one selection-bounds union.
    static func union(_ frames: [DesignRect]) -> DesignRect? {
        guard let minX = frames.map(\.x).min(), let minY = frames.map(\.y).min(),
            let maxX = frames.map(\.maxX).max(), let maxY = frames.map(\.maxY).max()
        else { return nil }
        return DesignRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
