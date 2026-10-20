// DesignFill+Kernel.swift: Design's workspace as the kernel's GradientFillTarget
// (gradient-fill DG-1 stubs, DG-4 bodies), so the eight `fill.*` commands and
// the inspector's Fill switch run on the selected layers. A layer keeps its
// gradient in a unit box over its frame; the selection maps it into the
// primary layer's frame in page points. A group has no fill. Linux-safe.
import SuiteKernel

extension DesignWorkspace: GradientFillTarget {
    /// The primary selected layer's fill in its frame; nil with nothing fillable selected.
    public var fillSelection: FillSelection? {
        guard let node = selectedNode, node.kind.fillLabel != nil else { return nil }
        let box = node.frame.kernelRect
        return FillSelection(fill: node.fill(in: box), box: box)
    }

    /// Why the fill commands can't run on the selection: nothing fillable selected, then the
    /// primary layer's lock. Stub: says gradients aren't built until DG-4.
    public var fillHelp: String? {
        guard let node = selectedNode, node.kind.fillLabel != nil else { return Self.selectToFillHelp }
        if let locked = lockHelp(node.id) { return locked }
        return DesignRefusal.notBuilt("Gradient fill").help
    }

    /// "Select a layer to fill.": the fill help with no layer, or only a group, selected.
    public static let selectToFillHelp = "Select a layer to fill."

    /// Sets every selected fillable layer's gradient, mapped from `box` to its unit box, as one
    /// step named `name`; steps under one `drag` fold into one. Stub: throws until DG-4.
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        throw GradientRules.notBuilt
    }

    /// Runs one fill editor gesture, the intent's command, through the workspace's catalog.
    /// Stub: does nothing until DG-4 adds the fill commands.
    public mutating func runFill(_ intent: GradientIntent) {}
}

extension DesignNode {
    /// The unit box a layer's gradient points are stored in.
    static let unitBox = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)

    /// This layer's paint with its points in `frame`: its gradient mapped from the unit box, or
    /// its solid `fill` as a 0...1 color.
    public func fill(in frame: Rect) -> Fill {
        if let gradient { return GradientRules.mapped(gradient, from: Self.unitBox, to: frame) }
        return .solid(FillColor(r: Double(fill.red) / 255, g: Double(fill.green) / 255, b: Double(fill.blue) / 255))
    }
}
