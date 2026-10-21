// DesignFill+Kernel.swift (gradient-fill DG-1 stubs, DG-4 bodies): Design's workspace is a kernel
// `GradientFillTarget`, so the eight fill commands in `GradientCommands` run on the selected layers the
// way Flare's and Halo's do. A node keeps its gradient in its unit box (0...1 across its frame); the
// selection reads the primary node's fill in its frame, in page points. `runFill` sends a fill editor
// gesture through `catalog`. Until DG-4 the set throws `GradientRules.notBuilt`, the catalog has no
// fill commands and `fillHelp` says so, so the Fill section's switch is off with that reason. Linux-safe.
import SuiteKernel

extension DesignWorkspace: GradientFillTarget {
    /// Why the fill commands can't run: nothing selected, the layer locked, or the stub's not-built reason.
    static let noFillSelection = "Select a layer to fill.", fillNotBuilt = "Gradient fills aren't built yet."

    /// The primary selected node's fill in its frame; nil with nothing selected.
    public var fillSelection: FillSelection? {
        guard let node = selectedNode else { return nil }
        let box = node.frame.kernelRect
        return FillSelection(fill: node.fill(in: box), box: box)
    }

    /// Why the fill commands can't run now; nil when they can. Stub: after the selection and lock checks it
    /// says gradients aren't built; DG-4 drops that line.
    public var fillHelp: String? {
        guard let node = selectedNode else { return Self.noFillSelection }
        if let locked = lockHelp(node.id) { return locked }
        return Self.fillNotBuilt
    }

    /// Sets every selected unlocked node's fill, mapped from `box` to its unit box, as one step named `name`;
    /// steps under one `drag` fold into one. Stub: refuses; DG-4 builds it.
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        throw GradientRules.notBuilt
    }

    /// Runs the fill editor's gesture as its command through `catalog`. A refusal changes nothing; the
    /// window shows `fillHelp` as the reason. Until DG-4 registers the fill specs every gesture refuses.
    public mutating func runFill(_ intent: GradientIntent) {
        let (id, params) = intent.command
        _ = try? Self.catalog.run(id, params: params, on: &self)
    }
}

extension DesignNode {
    /// This node's fill in `frame`'s space: its gradient mapped out of the unit box, or its solid colour.
    /// Stub: the gradient as stored; DG-4 maps it with `GradientRules.mapped`.
    public func fill(in frame: Rect) -> Fill {
        if let gradient { return gradient }
        return .solid(fill.kernelColor)
    }
}
