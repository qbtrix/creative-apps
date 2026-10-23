// FlareShape+Kernel.swift (shape-tools FS-1): FlareWorkspace adopts SuiteKernel's ShapeTarget. The Shape tool's
// options are view state (`shapeTool`, picked here, never an undo step); drawing a shape is a stub that refuses
// with ShapeRules.notBuilt and changes nothing until FS-6 builds `addShape` on LiveShapes' kernel paths.
import FlareCore
import SuiteKernel

extension FlareWorkspace: ShapeTarget {
    /// Why the Shape tool can't draw now: no animation open, else the tool's reason until FS-6.
    public var shapeHelp: String? {
        document == nil ? "Open or create an animation first." : FlareTool.shape.unavailableHelp
    }

    /// Records the Shape tool's options; the next drag draws with them.
    public mutating func pickShapeTool(_ spec: ShapeSpec) {
        shapeTool = spec
    }

    /// Adds one selected shape layer as one undo step named `name` (FS-6); refuses with nothing changed until then.
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        throw ShapeRules.notBuilt
    }
}
