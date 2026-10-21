// FlareStroke+Kernel.swift (stroke-style FK-1 stubs, FK-5 bodies): Flare's workspace is a kernel `StrokeTarget`, so
// the nine stroke commands in `StrokeCommands` run on the shapes the inspector paints. FlareCore's `Stroke` is already
// the kernel's `VectorStroke` (contract rule 20), so there is no mapping: the selection reads the first edited
// shape's stroke, and FK-5 sets every edited shape's stroke through `shape.setStroke` as one step, keying trim at the
// playhead when its track is animated. Until then `setStroke` throws `StrokeRules.notBuilt` and changes nothing.
import FlareCore
import SuiteKernel

extension FlareWorkspace: StrokeTarget {
    /// Why nothing can be stroked: no shape in the selection (a text-only one included, as it has no shape).
    static let noStrokeShape = "Select a shape layer."

    /// "Select a shape layer." with no shape to stroke; nil with one.
    public var strokeHelp: String? { paintShapes.isEmpty ? Self.noStrokeShape : nil }

    /// Flare trims, so trim never refuses for the app's sake.
    public var trimHelp: String? { nil }

    /// The first edited shape's stroke; nil with no shape or no stroke. Stub: the stored stroke; FK-5 samples trim
    /// at the playhead.
    public var selectedStroke: VectorStroke? { paintShapes.first?.1.stroke }

    /// Sets (nil removes) every edited shape's stroke as one step named `name`, folding under `drag`.
    /// Stub: refuses with `StrokeRules.notBuilt`; FK-5 builds it.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        throw StrokeRules.notBuilt
    }
}
