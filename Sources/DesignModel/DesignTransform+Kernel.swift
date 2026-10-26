// DesignTransform+Kernel.swift (transform DT-1 stubs, DT-5 bodies): Design's workspace is a kernel
// `TransformTarget`, so the six transform.* commands in `TransformCommands` turn, scale and mirror the
// selected layers the way the other apps' do. A node's `TransformBox` is its unturned `frame` with its
// `rotation`, `flipX` and `flipY`; no Design rotate maths, every point comes from `TransformRules`.
//
// - One layer: the box is its own, and `setTransform` writes it back as it is, so a turn keeps the
//   frame (and so the centre) and a flip keeps the frame.
// - Several: the box is the union of their turned outlines, upright. Each layer turns and mirrors
//   about its own centre, and that centre goes where the union's matrix takes it, so the whole
//   selection turns about the union's centre. A layer inside another selected one goes with it.
// - Every write is one step named after the command; steps under one `drag` token on the same layers
//   fold into one. A locked layer, or one inside a locked group, refuses with `transformHelp`.
// - `contains` hit-tests the turned outline: the point taken into the box's own frame.
//
// `runTransform` sends an inspector, menu or knob gesture through `catalog`, which registers the six
// specs (DT-6); `turnHelp` is the rows' reason, `transformHelp`. Linux-safe.
import SuiteKernel

// `transformHelp`, the requirement's "why not", is the workspace's own (DesignActions): the help a
// drag's move and resize already give, nothing selected, editing text, or a locked layer.
extension DesignWorkspace: TransformTarget {
    /// One selected node: its box. Several: the union of their turned outlines, upright. Nil with none.
    public var transformSelection: TransformBox? {
        let boxes = transformRoots.map(\.transformBox)
        guard boxes.count > 1 else { return boxes.first }
        return DesignRect.union(boxes.map { DesignRect(TransformRules.bounds(of: $0)) }).map { TransformBox(box: $0.kernelRect) }
    }

    /// Why the inspector's Rotation and Flip rows and Object's turn and flip items are off; nil when they
    /// can act: `transformHelp`.
    public var turnHelp: String? { transformHelp }

    /// Sets every selected node's box, each about its share of the selection, as one step named `name`;
    /// steps under one `drag` fold into one. A selection `transformHelp` refuses throws that help.
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        if let help = transformHelp { throw DesignRefusal.notYet(help) }
        guard let current = transformSelection else { throw DesignRefusal.nothingSelected }
        let roots = transformRoots
        let key = drag.map { CoalesceKey.key("transform", on: roots.map(\.id), drag: $0) }
        let one = roots.count == 1
        let before = snapshot
        for root in roots { _ = pages.update(root.id) { $0.place(one ? t : Self.share(of: root.transformBox, from: current, to: t)) } }
        record(name, before: before, coalescing: key)
    }

    /// Runs a transform gesture as its command through `catalog`. A refusal changes nothing; the window
    /// shows `transformHelp` as the reason.
    public mutating func runTransform(_ intent: TransformIntent) {
        let (id, params) = intent.command
        _ = try? Self.catalog.run(id, params: params, on: &self)
    }

    /// The selected nodes on the selected page, without one inside another selected node.
    var transformRoots: [DesignNode] {
        guard let page = selectedPage else { return [] }
        let ids = Set(selectedNodeIDs)
        return selectedNodes.filter { !(page.nodes.ancestors(of: $0.id) ?? []).contains(where: ids.contains) }
    }

    /// Where `node`, part of the selection box `old`, lands when that box becomes `new`: mirrored and
    /// turned about its own centre as the box was, sized by the box's scale, its centre where `new`'s
    /// matrix takes the centre's place in `old`. An axis on which `old` has no size keeps the middle.
    static func share(of node: TransformBox, from old: TransformBox, to new: TransformBox) -> TransformBox {
        var moved = node
        if new.flipX != old.flipX { moved = TransformRules.flipped(moved, .horizontal) }
        if new.flipY != old.flipY { moved = TransformRules.flipped(moved, .vertical) }
        moved = TransformRules.rotated(moved, by: new.degrees - old.degrees)
        let (w, h) = (old.box.width, old.box.height)
        let local = TransformRules.local(Point(x: (node.box.minX + node.box.maxX) / 2, y: (node.box.minY + node.box.maxY) / 2), in: old)
        let unit = Point(x: w > 0 ? (local.x - old.box.minX) / w : 0.5, y: h > 0 ? (local.y - old.box.minY) / h : 0.5)
        let centre = TransformRules.matrix(of: new).apply(unit)
        let size = (node.box.width * (w > 0 ? new.box.width / w : 1), node.box.height * (h > 0 ? new.box.height / h : 1))
        moved.box = Rect(minX: centre.x - size.0 / 2, minY: centre.y - size.1 / 2, maxX: centre.x + size.0 / 2, maxY: centre.y + size.1 / 2)
        return moved
    }
}

extension DesignNode {
    /// This node's frame, turn and mirrors as the kernel's box.
    public var transformBox: TransformBox {
        TransformBox(box: frame.kernelRect, degrees: rotation, flipX: flipX, flipY: flipY)
    }

    /// Whether `point` is inside the node's turned outline; the edges count. `[DesignNode].hit(at:)` asks
    /// this. The point is taken into the box's own unturned frame (`TransformRules.local`).
    public func contains(_ point: DesignPoint) -> Bool {
        let local = TransformRules.local(Point(x: point.x, y: point.y), in: transformBox)
        return frame.contains(DesignPoint(x: local.x, y: local.y))
    }

    /// Takes `t` as this node's frame, turn and mirrors; its subtree moves with the frame's corner.
    mutating func place(_ t: TransformBox) {
        let moved = DesignRect(t.box)
        let delta = DesignPoint(x: moved.x - frame.x, y: moved.y - frame.y)
        for index in children.indices { children[index].translate(by: delta) }
        (frame, rotation, flipX, flipY) = (moved, t.degrees, t.flipX, t.flipY)
    }
}
