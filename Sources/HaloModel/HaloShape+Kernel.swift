// HaloShape+Kernel.swift: Halo's project as the kernel's ShapeTarget
// (shape-tools HS-1 stubs, HS-5 bodies), so `shape.draw`, `tool.shape` and
// the Shape button's options run on the selected composition. A drawn shape
// is a new shape layer at the playhead's span, its ShapeSpec in
// `HaloLayer.shape`, selected, as one undo step. Linux-safe.
import SuiteKernel

extension HaloProject: ShapeTarget {
    /// Why the Shape button can't draw: no composition, or the stub's reason
    /// until HS-5 builds the tool.
    public var shapeHelp: String? {
        selectedComposition == nil ? "Make a composition first." : "Shape tools aren't built yet."
    }

    /// The spec the next drag draws. Stub: the default rectangle until HS-5.
    public var shapeTool: ShapeSpec { .defaults(.rectangle) }

    /// Keeps `spec` as the tool's next shape. Stub: does nothing until HS-5.
    public mutating func pickShapeTool(_ spec: ShapeSpec) {}

    /// Adds a shape layer named `name` drawing `spec` in `box` (composition
    /// pixels), selects it and returns its id. Stub: throws until HS-5.
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        throw ShapeRules.notBuilt
    }

    /// Runs one option the Shape popover sends through the project's command
    /// catalog (`tool.shape`). Stub: does nothing until HS-5.
    public mutating func runShape(_ intent: ShapeIntent) {}
}
