// FlareFill+Kernel.swift (gradient-fill FG-1 stubs, FG-5 bodies): Flare's workspace is a kernel `GradientFillTarget`,
// so the eight fill commands in `GradientCommands` run on the shapes the inspector paints. The selection reads the first
// of those shapes' fill in its own bounds (a shape's gradient points are in its local space); `runFill` sends an editor
// gesture through `catalog`, and a refusal lands in `paintError`. Until FG-5 the set throws `GradientRules.notBuilt`
// and the catalog has no fill commands, so `fillHelp` says so, every gesture refuses and changes nothing.
import FlareCore
import SuiteKernel

extension FlareWorkspace: GradientFillTarget {
    /// Why fill editing can't run while the catalog has no fill commands; FG-5 registers them and retires it.
    public static let fillNotBuilt = "Gradient fills aren't built yet."

    /// The first edited shape's fill in its bounds; nil with no shape.
    public var fillSelection: FillSelection? {
        guard let shape = paintShapes.first?.1 else { return nil }
        return FillSelection(fill: shape.fill, box: shape.bounds ?? FlareCore.Rect(minX: 0, minY: 0, maxX: 0, maxY: 0))
    }

    /// Why the fill commands can't run: FlarePaint's "no shape" reason, or the not-built reason while the catalog has
    /// no fill commands; nil with a shape to paint and the commands registered.
    public var fillHelp: String? {
        if paintShapes.isEmpty { return Self.noShape }
        return Self.catalog.spec(GradientIntent.type(.solid).command.id) == nil ? Self.fillNotBuilt : nil
    }

    /// Sets every edited shape's fill, mapped from `box` to its bounds, as one step. Stub: refuses; FG-5 builds it.
    public mutating func setFill(_ fill: FlareCore.Fill, in box: FlareCore.Rect, name: String, drag: String?) throws {
        throw GradientRules.notBuilt
    }

    /// Runs the editor's gesture as its command through `catalog`; a refusal lands in `paintError`.
    public mutating func runFill(_ intent: GradientIntent) {
        let (id, params) = intent.command
        do {
            _ = try Self.catalog.run(id, params: params, on: &self)
            paintError = nil
        } catch {
            paintError = error.description
        }
    }
}
