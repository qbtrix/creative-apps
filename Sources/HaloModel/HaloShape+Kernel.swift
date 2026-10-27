// HaloShape+Kernel.swift: Halo's project as the kernel's ShapeTarget
// (shape-tools HS-1 stubs, HS-5 bodies), so `shape.draw`, `tool.shape` and
// the Shape button's options run on the selected composition. A drawn shape
// is a new shape layer at the playhead's span, its ShapeSpec in
// `HaloLayer.shape` and its box in `HaloLayer.rect`, selected, as one undo
// step. The layer is named by its kind ("Star 1"); the undo step takes the
// caller's name ("Draw Star"). A line or arrow has nothing to fill, so it
// starts with a 4 pt stroke in the layer's colour. Linux-safe.
import FlareCore
import SuiteKernel

extension HaloProject: ShapeTarget {
    /// Why the Shape button can't draw: nil once a composition is selected.
    public var shapeHelp: String? {
        selectedComposition == nil ? "Make a composition first." : nil
    }

    /// Keeps `spec` as the tool's next shape. View state, not an undo step.
    public mutating func pickShapeTool(_ spec: ShapeSpec) { shapeTool = spec }

    /// Adds a shape layer named by its kind and number ("Star 1") drawing
    /// `spec` in `box` (composition pixels) from the playhead to the end,
    /// selects it and returns its id, as one undo step named `name`. Throws
    /// `ShapeRefusal` with no composition or a bad spec.
    public mutating func addShape(_ spec: ShapeSpec, in box: Rect, name: String) throws -> String {
        guard let comp = selectedComposition else { throw ShapeRefusal.invalid("Make a composition first.") }
        if let help = ShapeRules.help(spec) { throw ShapeRefusal.invalid(help) }
        var added: String?
        _ = edit(name, control: "halo.shape.draw") { doc in
            guard let index = doc.compositions.firstIndex(where: { $0.id == comp.id }) else { return }
            let title = spec.kind.rawValue.prefix(1).uppercased() + spec.kind.rawValue.dropFirst()
            let number = doc.compositions[index].layers.filter { $0.shape?.kind == spec.kind }.count + 1
            let color = HaloLayerKind.shape.defaultColor
            var layer = HaloLayer(
                id: doc.takeLayerID(in: comp.id), name: "\(title) \(number)", kind: .shape, inFrame: comp.playheadFrame,
                outFrame: max(comp.durationFrames, comp.playheadFrame + 1), color: color)
            layer.rect = HaloLayerRect(x: box.minX, y: box.minY, width: box.width, height: box.height)
            layer.shape = spec
            if spec.kind == .line || spec.kind == .arrow {
                layer.stroke = VectorStroke(color: Color(r: color.red, g: color.green, b: color.blue), width: 4)
            }
            doc.compositions[index].layers.insert(layer, at: 0)
            doc.selectedLayerID = layer.id
            added = layer.id
        }
        guard let added else { throw ShapeRefusal.invalid("That shape couldn't be drawn.") }
        return added
    }

    /// Runs one option the Shape popover sends through the project's command
    /// catalog (`tool.shape`); a refused option keeps the tool as it was.
    public mutating func runShape(_ intent: ShapeIntent) {
        let command = intent.command
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }
}
