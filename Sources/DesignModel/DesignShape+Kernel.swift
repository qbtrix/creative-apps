// DesignShape+Kernel.swift (shape-tools DS-1 contract, DS-5 bodies): Design's workspace is a kernel `ShapeTarget`,
// so the Shape tool's options panel, shape.draw and tool.shape run on it the way they do in the other apps. The
// tool's options are view state (`shapeTool`, picked here, never an undo step). Every box and path comes from
// `ShapeRules` (dragged, path, help); no Design shape maths. A shape node is a `.shape` node carrying its spec,
// which the file keeps, and its path is the spec's in the node's frame. Linux-safe.
import SuiteKernel

extension DesignWorkspace: ShapeTarget {
    /// Why the Shape tool can't draw now: no file open, else the tool's own reason (none once it works).
    public var shapeHelp: String? {
        pages.isEmpty ? "Open or create a design first." : DesignTool.shape.unavailableHelp
    }

    /// Records the Shape tool's options; the next drag draws with them.
    public mutating func pickShapeTool(_ spec: ShapeSpec) {
        shapeTool = spec
    }

    /// Adds one selected shape node drawing `spec` in `box` as one undo step named `name`, and returns its id.
    /// It goes inside the deepest frame under the box's top-left corner. Refused while `shapeHelp` is set or
    /// when the kernel's `help` refuses the spec, changing nothing.
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        try addShape(spec, frame: DesignRect(box), at: DesignPoint(x: box.minX, y: box.minY), name: name)
    }

    /// `addShape` in `frame`, inside the deepest frame under `point` (a drag's start).
    mutating func addShape(_ spec: ShapeSpec, frame: DesignRect, at point: DesignPoint, name: String) throws -> String {
        if let help = shapeHelp ?? ShapeRules.help(spec) { throw ShapeRefusal.invalid(help) }
        let before = snapshot
        let parent = selectedPage?.nodes.deepestFrame(containing: point)
        let id = try insertNode(.shape, frame: frame, in: parent)
        _ = pages.update(id) { $0.shape = spec }
        record(name, before: before)
        return id
    }

    /// Applies one change the inspector's Shape options ask for to the tool's next spec.
    public mutating func runShape(_ intent: ShapeIntent) {
        pickShapeTool(intent.applied(to: shapeTool))
    }
}

extension DesignNode {
    /// The spec's path in `frame` (document space), from `ShapeRules.path`; nil for other kinds.
    public func path(in frame: DesignRect) -> VectorPath? {
        guard kind == .shape, let shape else { return nil }
        return try? ShapeRules.path(shape, in: frame.kernelRect)
    }
}
