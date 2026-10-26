// DesignFill+Kernel.swift (gradient-fill DG-1 stubs, DG-4 bodies): Design's workspace is a kernel
// `GradientFillTarget`, so the eight fill commands in `GradientCommands` run on the selected layers the
// way Flare's and Halo's do. A node keeps its gradient in its unit box (0...1 across its frame), so a
// resize never touches it; the selection reads the primary node's fill in its frame, in page points.
// `setFill` maps the fill back into the unit box on every selected unlocked layer as one step, and
// `runFill` sends a fill editor gesture through `catalog`. Linux-safe.
import SuiteKernel

extension DesignWorkspace: GradientFillTarget {
    /// Why the fill commands can't run with nothing selected.
    static let noFillSelection = "Select a layer to fill."

    /// The primary selected node's fill in its frame; nil with nothing selected.
    public var fillSelection: FillSelection? {
        guard let node = selectedNode else { return nil }
        let box = node.frame.kernelRect
        return FillSelection(fill: node.fill(in: box), box: box)
    }

    /// Why the fill commands can't run now: nothing selected, a text edit open, or the primary layer locked
    /// (its lock help); nil when they can.
    public var fillHelp: String? {
        guard let node = selectedNode else { return Self.noFillSelection }
        if editingTextID != nil { return styleHelp(.fill) }
        return lockHelp(node.id)
    }

    /// Sets every selected unlocked node's fill, mapped from `box` to its unit box, as one step named `name`;
    /// steps under one `drag` fold into one. A solid writes the node's colour and clears its gradient; a fill
    /// that changes nothing (Linear on a linear gradient) refuses with `.unchanged`, as Design's other edits do.
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        if let why = fillHelp { throw CatalogError.failed(id: "fill", message: why) }
        guard gesture == nil else { throw CatalogError.failed(id: "fill", message: "Finish the drag first.") }
        let unit = GradientRules.mapped(fill, from: box, to: DesignNode.unitBox)
        let ids = selectedNodeIDs.filter { !isLockedInTree($0) }
        let before = snapshot
        for id in ids { _ = pages.update(id) { $0.paint(unit) } }
        guard snapshot != before else { throw DesignRefusal.unchanged }
        record(name, before: before, coalescing: drag.map { "gradient-" + $0 })
    }

    /// Runs the fill editor's gesture as its command through `catalog`. A refusal changes nothing; the
    /// window shows `fillHelp` as the reason.
    public mutating func runFill(_ intent: GradientIntent) {
        let (id, params) = intent.command
        _ = try? Self.catalog.run(id, params: params, on: &self)
    }
}

extension DesignNode {
    /// The box a node's gradient points live in: 0...1 across its frame.
    static let unitBox = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)

    /// This node's fill in `frame`'s space: its gradient mapped out of the unit box, or its solid colour.
    public func fill(in frame: Rect) -> Fill {
        if let gradient { return GradientRules.mapped(gradient, from: Self.unitBox, to: frame) }
        return .solid(fill.kernelColor)
    }

    /// Paints this node with `unit`, a fill in its unit box: a solid sets its colour and clears the gradient.
    mutating func paint(_ unit: Fill) {
        if case .solid(let color) = unit {
            (fill, gradient) = (DesignColor(kernel: color), nil)
        } else {
            gradient = unit
        }
    }
}
