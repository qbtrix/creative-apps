// HaloFill+Kernel.swift: Halo's project as the kernel's GradientFillTarget
// (gradient-fill HG-1 stubs, HG-7 bodies), so the eight `fill.*` commands
// and the fill editor's gestures run on the selected solid or shape layer.
// A layer keeps its gradient in a unit box over its bounds; the selection
// maps it into the layer's box in composition pixels. Text and null layers
// have no fill. Linux-safe.
import SuiteKernel

extension HaloProject: GradientFillTarget {
    /// Why the fill commands can't run: nothing selected, a text layer or a null.
    static let noFillLayer = "Select a solid or shape layer to fill.",
        textFillHelp = "A text layer takes a color, not a gradient.",
        nullFillHelp = "A null layer has nothing to fill."

    /// The selected solid's or shape's fill in its box; nil for text, null or
    /// no selection.
    public var fillSelection: FillSelection? {
        guard fillHelp == nil, let comp = selectedComposition, let layer = selectedLayer else { return nil }
        let box = layer.fillBox(in: comp)
        return FillSelection(fill: layer.fill(in: box), box: box)
    }

    /// Why the fill commands can't run on the selection; nil on a solid or shape.
    public var fillHelp: String? {
        guard selectedComposition != nil, let layer = selectedLayer else { return Self.noFillLayer }
        switch layer.kind {
        case .solid, .shape: return nil
        case .text: return Self.textFillHelp
        case .null: return Self.nullFillHelp
        }
    }

    /// Sets the selected layer's gradient, mapped from `box` to its unit box,
    /// as one step named `name`; steps under one `drag` fold into one. A solid fill drops
    /// the gradient and sets the layer's color. Throws on text, null or no
    /// selection, changing nothing.
    public mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        if let fillHelp { throw CatalogError.failed(id: "fill", message: fillHelp) }
        let key = drag.flatMap { drag in selectedLayerID.map { "\($0).fill.\(drag)" } }
        let set = edit(name, control: "halo.fill", coalesceKey: key) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            doc.compositions[c].layers[l].setFill(fill, from: box)
        }
        if !set { throw CatalogError.failed(id: "fill", message: refusal?.message ?? Self.noFillLayer) }
    }

    /// Runs one fill editor gesture through the project's command catalog; a
    /// refused gesture changes nothing.
    public mutating func runFill(_ intent: GradientIntent) {
        let command = intent.command
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }
}

extension HaloLayer {
    /// The box a gradient's unit box maps onto: the layer's bounds in
    /// composition pixels.
    func fillBox(in composition: HaloComposition) -> Rect {
        let b = bounds(in: composition)
        return Rect(minX: b.x, minY: b.y, maxX: b.x + b.width, maxY: b.y + b.height)
    }

    /// This layer's fill in `box`: its gradient mapped out of the unit box, or
    /// its solid color.
    func fill(in box: Rect) -> Fill {
        guard let gradient else { return .solid(FillColor(r: color.red, g: color.green, b: color.blue, a: 1)) }
        return GradientRules.mapped(gradient, from: Self.unitBox, to: box)
    }

    /// Stores `fill`, whose points are in `box`, in the unit box; a solid
    /// clears the gradient and becomes the layer's color.
    mutating func setFill(_ fill: Fill, from box: Rect) {
        if case .solid(let c) = fill {
            gradient = nil
            color = HaloLayerColor(red: c.r, green: c.g, blue: c.b)
        } else {
            gradient = GradientRules.mapped(fill, from: box, to: Self.unitBox)
        }
    }

    /// The unit box a stored gradient's points are in.
    static let unitBox = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)
}
