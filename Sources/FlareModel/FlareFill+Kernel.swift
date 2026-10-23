// FlareFill+Kernel.swift (gradient-fill FG-1 stubs, FG-5 bodies): Flare's workspace is a kernel `GradientFillTarget`,
// so the eight fill commands in `GradientCommands` run on the shapes the inspector paints. The selection reads the first
// of those shapes' fill in its own bounds (a shape's gradient points are in its local space); `setFill` maps the new
// fill from that box into each shape's bounds and writes them all through `services.properties` as one undo step
// named by the command. Under a drag token each write is a top-level `SetShapeFill` under one coalesce key instead
// (an engine group ends coalescing), so a stop drag is one undo entry. `runFill` sends an editor gesture through
// `catalog`, and a refusal lands in `paintError`. Linux-safe.
import FlareCore
import SuiteKernel

extension FlareWorkspace: GradientFillTarget {
    /// The first edited shape's fill in its bounds; nil with no shape.
    public var fillSelection: FillSelection? {
        guard let shape = paintShapes.first?.1 else { return nil }
        return FillSelection(fill: shape.fill, box: shape.bounds ?? FlareCore.Rect(minX: 0, minY: 0, maxX: 0, maxY: 0))
    }

    /// Why the fill commands can't run: FlarePaint's "no shape" reason; nil with a shape to paint.
    public var fillHelp: String? {
        if paintShapes.isEmpty { return Self.noShape }
        return nil
    }

    /// Sets every edited shape's fill, mapped from `box` to its bounds, as one step named `name`; writes under one
    /// `drag` token fold into one undo entry.
    public mutating func setFill(_ fill: FlareCore.Fill, in box: FlareCore.Rect, name: String, drag: String?) throws {
        let found = paintShapes
        guard !found.isEmpty else { throw CatalogError.failed(id: "fill", message: Self.noShape) }
        let writes = found.map { address, shape in
            (address, GradientRules.mapped(fill, from: box, to: shape.bounds ?? box))
        }
        if let drag {
            step { engine in
                for (a, f) in writes { if case .shape(let i) = a.item {
                    try engine.perform(SetShapeFill(owner: a.owner, layerID: a.layerID, index: i, fill: f),
                                       coalesceKey: "fill-\(drag)")
                } }
            }
        } else {
            let properties = services.properties
            step(name) { engine in for (a, f) in writes { try properties.setFill(f, of: [a], in: &engine) } }
        }
        paintError = layerError?.message
        if let layerError { throw CatalogError.failed(id: "fill", message: layerError.message) }
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
