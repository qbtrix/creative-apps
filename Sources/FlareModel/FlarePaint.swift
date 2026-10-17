// FlarePaint.swift: fill and stroke on the workspace (inspector-timeline IT-2). `paint` reads the shapes the inspector
// edits: the direct-selected shapes under Direct Select, else every shape of the inspector's layers; a value that
// differs across them reads nil (Mixed), and a shape with no stroke reads as a zero-width one. Each setter is one undo
// step through `services.properties` ("Set Fill" / "Set Stroke"); a bad hex, a gradient fill or no shape refuses with
// a reason in `paintError` and changes nothing, and a successful set clears it. Hex parsing is NewDocumentSpec's.
import FlareCore

/// The selection's fill and stroke as the inspector shows them. A nil value reads as Mixed.
public struct PaintReadout: Sendable, Equatable {
    public var fillHex: String?, fillIsGradient: Bool
    public var strokeHex: String?, strokeWidth: Double?, cap: Stroke.Cap?, join: Stroke.Join?

    public init(fillHex: String?, fillIsGradient: Bool, strokeHex: String?, strokeWidth: Double?,
                cap: Stroke.Cap?, join: Stroke.Join?) {
        (self.fillHex, self.fillIsGradient) = (fillHex, fillIsGradient)
        (self.strokeHex, self.strokeWidth, self.cap, self.join) = (strokeHex, strokeWidth, cap, join)
    }
}

extension FlareWorkspace {
    static let badHex = "Use 6 hex digits, like FF3B30."
    static let gradientRefusal = "Gradients can't be edited yet."
    static let noShape = "Select a shape first."

    /// The fill and stroke of the shapes the inspector edits; nil with none.
    public var paint: PaintReadout? {
        let found = paintShapes.map(\.1)
        guard !found.isEmpty else { return nil }
        let strokes = found.map { $0.stroke ?? Self.noStroke }
        let fills = found.map(\.fill)
        let solid: [String] = fills.compactMap { if case .solid(let c) = $0 { Self.hexDigits(c) } else { nil } }
        return PaintReadout(
            fillHex: solid.count == fills.count ? Self.same(solid) : nil,
            fillIsGradient: solid.count < fills.count,
            strokeHex: Self.same(strokes.map { Self.hexDigits($0.color) }), strokeWidth: Self.same(strokes.map(\.width)),
            cap: Self.same(strokes.map(\.cap)), join: Self.same(strokes.map(\.join)))
    }

    /// Sets the selection's solid fill; refuses a bad hex or a gradient with a reason.
    public mutating func setFill(hex: String) {
        guard let color = NewDocumentSpec.color(hex: hex) else { return paintError = Self.badHex }
        let found = paintShapes
        guard !found.isEmpty else { return paintError = Self.noShape }
        guard found.allSatisfy({ if case .solid = $0.1.fill { true } else { false } }) else {
            return paintError = Self.gradientRefusal
        }
        let properties = services.properties, items = found.map(\.0)
        paintStep(nil) { try properties.setFill(.solid(color), of: items, in: &$0) }
    }

    /// Sets the stroke width, called once on the bar's release.
    public mutating func setStrokeWidth(_ width: Double) { editStroke { $0.width = width } }

    /// Sets the stroke cap.
    public mutating func setStrokeCap(_ cap: Stroke.Cap) { editStroke { $0.cap = cap } }

    /// Sets the stroke join.
    public mutating func setStrokeJoin(_ join: Stroke.Join) { editStroke { $0.join = join } }

    /// Sets the stroke color; refuses a bad hex with a reason.
    public mutating func setStrokeColor(hex: String) {
        guard let color = NewDocumentSpec.color(hex: hex) else { return paintError = Self.badHex }
        editStroke { $0.color = color }
    }

    /// A shape with no stroke reads, and is edited, as this one.
    private static let noStroke = Stroke(width: 0)

    /// The shape addresses the inspector paints, each with its shape.
    private var paintShapes: [(StageAddress, FlareShape)] {
        guard let document, let owner = propertyOwner else { return [] }
        let direct = tool == .directSelect && !selection.isEmpty
        let items = direct ? selection : propertyLayerIDs.flatMap { id in
            (document.layers(of: owner)?.first { $0.id == id }?.shapes.indices).map { $0.map {
                StageAddress(owner: owner, layerID: id, item: .shape($0))
            } } ?? []
        }
        return items.compactMap { a in
            guard case .shape(let i) = a.item,
                  let shapes = document.layers(of: a.owner)?.first(where: { $0.id == a.layerID })?.shapes,
                  shapes.indices.contains(i) else { return nil }
            return (a, shapes[i])
        }
    }

    /// One "Set Stroke" step: `change` applied to each shape's own stroke, so a field the set doesn't name stays.
    private mutating func editStroke(_ change: (inout Stroke) -> Void) {
        let found = paintShapes
        guard !found.isEmpty else { return paintError = Self.noShape }
        var batches: [(Stroke, [StageAddress])] = []
        for (address, shape) in found {
            var stroke = shape.stroke ?? Self.noStroke
            change(&stroke)
            if let i = batches.firstIndex(where: { $0.0 == stroke }) { batches[i].1.append(address) }
            else { batches.append((stroke, [address])) }
        }
        let properties = services.properties
        paintStep(batches.count > 1 ? "Set Stroke" : nil) { engine in
            for (stroke, items) in batches { try properties.setStroke(stroke, of: items, in: &engine) }
        }
    }

    /// Runs one undo step; a refusal lands in `paintError` too, and a success clears it.
    private mutating func paintStep(_ label: String?, _ body: (inout CommandEngine) throws -> Void) {
        step(label, body)
        paintError = layerError?.message
    }

    /// "RRGGBB" for `color`.
    private static func hexDigits(_ color: FlareColor) -> String { String(NewDocumentSpec.hex(color).dropFirst()) }

    /// The one value all of `values` share; nil when they differ or there are none.
    private static func same<T: Equatable>(_ values: [T]) -> T? {
        guard let first = values.first, values.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
}
