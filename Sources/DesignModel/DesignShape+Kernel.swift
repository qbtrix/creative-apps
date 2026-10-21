// DesignShape+Kernel.swift (shape-tools DS-1 stubs, DS-5 bodies): Design's workspace is a kernel `ShapeTarget`,
// so the Shape tool's options panel, shape.draw and tool.shape run on it the way they do in the other apps. The
// tool's options are view state (`shapeTool`, picked here, never an undo step). Every box and path comes from
// `ShapeRules` (dragged, path, help); no Design shape maths. Until DS-5 `addShape` refuses with
// `ShapeRules.notBuilt` and changes nothing, and a node's `path(in:)` is nil. Linux-safe.
import SuiteKernel

extension DesignWorkspace: ShapeTarget {
    /// Why the Shape tool can't draw now: no file open, else the tool's reason until DS-5.
    public var shapeHelp: String? {
        pages.isEmpty ? "Open or create a design first." : DesignTool.shape.unavailableHelp
    }

    /// Records the Shape tool's options; the next drag draws with them.
    public mutating func pickShapeTool(_ spec: ShapeSpec) {
        shapeTool = spec
    }

    /// Adds one selected shape node drawing `spec` in `box` as one undo step named `name`, and returns its id.
    /// Stub: refuses with nothing changed; DS-5 builds it.
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        throw ShapeRules.notBuilt
    }

    /// Applies one change the inspector's Shape options ask for to the tool's next spec.
    public mutating func runShape(_ intent: ShapeIntent) {
        pickShapeTool(intent.applied(to: shapeTool))
    }
}

extension DesignNode {
    /// The spec's path in `frame` (document space), from `ShapeRules.path`; nil for other kinds.
    /// Stub: nil until DS-5.
    public func path(in frame: DesignRect) -> VectorPath? {
        nil
    }
}
