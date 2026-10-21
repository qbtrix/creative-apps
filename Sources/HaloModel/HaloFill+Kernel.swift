// HaloFill+Kernel.swift: Halo's project as the kernel's GradientFillTarget
// (gradient-fill HG-1 stubs, HG-7 bodies), so the eight `fill.*` commands
// and the fill editor's gestures run on the selected solid or shape layer.
// A layer keeps its gradient in a unit box over its bounds; the selection
// maps it into the layer's box in composition pixels. Text and null layers
// have no fill. Linux-safe.
import SuiteKernel

extension HaloProject: GradientFillTarget {
    /// The selected solid's or shape's fill in its box; nil for text, null or
    /// no selection. Stub: nil until HG-7.
    public var fillSelection: FillSelection? { nil }

    /// Why the fill commands can't run on the selection. Stub until HG-7.
    public var fillHelp: String? { "Gradient fills aren't built yet." }

    /// Sets the selected layer's gradient, mapped from `box` to its unit box,
    /// as one step named `name`; steps under one `drag` fold into one. Stub:
    /// throws until HG-7.
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        throw GradientRules.notBuilt
    }

    /// Runs one fill editor gesture through the project's command catalog.
    /// Stub: does nothing until HG-7.
    public mutating func runFill(_ intent: GradientIntent) {}
}
