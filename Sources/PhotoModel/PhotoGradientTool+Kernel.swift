// PhotoGradientTool+Kernel.swift (gradient-fill PG-1 stubs; PG-3 and PG-4
// bodies): the Gradient tool's adapter onto the kernel. The tool's options
// hold SuiteKernel's `Fill`, edited through `GradientRules` by the editor's
// `GradientIntent`s, and its pixels are creative-core's raster gradient
// (rule 20: no Photo gradient type). A drag's release calls `drawGradient`
// (PhotoStroke.swift's `endDrag`). Both are stubs that change nothing, so the
// tool keeps its help "Not built yet (PG-3)." until PG-3. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace {
    /// Draws the tool's gradient into the selected layer, inside the selection
    /// when there is one, from `a` (offset 0) to `b` (offset 1) in canvas
    /// pixels, as one "Gradient" undo step. Stub: draws nothing; PG-3 builds it.
    public mutating func drawGradient(from a: Mask.Point, to b: Mask.Point) throws {}

    /// One editor gesture on the tool's gradient (`toolOptions.gradient`),
    /// through `GradientRules`; not undoable, as every tool option. Stub:
    /// changes nothing; PG-4 builds it.
    public mutating func runGradientOption(_ intent: GradientIntent) {}
}
