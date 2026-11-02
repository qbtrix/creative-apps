// FlarePaint.swift: fill and stroke on the workspace (inspector-timeline IT-2). `paint` reads the shapes the inspector
// edits: the direct-selected shapes under Direct Select, else every shape of the inspector's layers; a value that
// differs across them reads nil (Mixed), and a shape with no stroke reads as a zero-width one. Each setter is one undo
// step through `services.properties` ("Set Fill" / "Set Stroke"). The Width bar's drag is `scrubStrokeWidth`: every
// sample lands on the shapes at once, and the samples coalesce into one "Set Stroke" step until `endPropertyScrub()`,
// the end the TRANSFORM rows' scrub uses too (FlareAnimate.swift). A bad hex or no shape refuses with a reason in
// `paintError` and changes nothing, and a successful set clears it. Hex parsing is NewDocumentSpec's. `gradient`
// (gradient-fill FG-1, FG-6) is the first shape's gradient in its bounds when every edited shape has that same
// gradient, nil (Mixed) when they differ; a hex set turns a gradient solid.
import FlareCore
import SuiteKernel

/// The selection's fill and stroke as the inspector shows them. A nil value reads as Mixed.
public struct PaintReadout: Sendable, Equatable {
    public var fillHex: String?, fillIsGradient: Bool
    public var strokeHex: String?, strokeWidth: Double?, cap: Stroke.Cap?, join: Stroke.Join?
    /// The gradient the editor shows; nil for a solid or Mixed.
    public var gradient: FillSelection?

    public init(fillHex: String?, fillIsGradient: Bool, strokeHex: String?, strokeWidth: Double?,
                cap: Stroke.Cap?, join: Stroke.Join?, gradient: FillSelection? = nil) {
        (self.fillHex, self.fillIsGradient, self.gradient) = (fillHex, fillIsGradient, gradient)
        (self.strokeHex, self.strokeWidth, self.cap, self.join) = (strokeHex, strokeWidth, cap, join)
    }
}

extension FlareWorkspace {
    static let badHex = "Use 6 hex digits, like FF3B30."
    static let noShape = "Select a shape first."

    /// The fill and stroke of the shapes the inspector edits; nil with none.
    public var paint: PaintReadout? {
        let found = shownPaintShapes
        guard !found.isEmpty else { return nil }
        let strokes = found.map { $0.stroke ?? Self.noStroke }
        let fills = found.map(\.fill)
        let solid: [String] = fills.compactMap { if case .solid(let c) = $0 { Self.hexDigits(c) } else { nil } }
        return PaintReadout(
            fillHex: solid.count == fills.count ? Self.same(solid) : nil,
            fillIsGradient: solid.count < fills.count,
            strokeHex: Self.same(strokes.map { Self.hexDigits($0.color) }), strokeWidth: Self.same(strokes.map(\.width)),
            cap: Self.same(strokes.map(\.cap)), join: Self.same(strokes.map(\.join)),
            gradient: solid.isEmpty && Self.same(fills) != nil ? fillSelection : nil)
    }

    /// Sets the selection's solid fill, a gradient included; refuses a bad hex with a reason.
    public mutating func setFill(hex: String) {
        guard let color = NewDocumentSpec.color(hex: hex) else { return paintError = Self.badHex }
        let found = paintShapes
        guard !found.isEmpty else { return paintError = Self.noShape }
        let properties = services.properties, split = found.map { ($0.0, fillKey($0.0, color)) }
        let items = split.filter { $0.1 == nil }.map(\.0), keys = split.compactMap(\.1)
        paintStep(keys.isEmpty ? nil : "Set Fill") { engine in
            try properties.setFill(.solid(color), of: items, in: &engine)
            try properties.keyPaint(keys, coalesceKey: nil, in: &engine)
        }
    }

    /// Sets the stroke width as one undo step.
    public mutating func setStrokeWidth(_ width: Double) { editStroke { $0.width = width } }

    /// Sets the stroke width during a Width bar drag: shown at once, and every sample until `endPropertyScrub()` shares
    /// one undo step.
    public mutating func scrubStrokeWidth(_ width: Double) {
        let items = paintShapes.map(\.0)
        editStroke(coalesceKey: CoalesceKey.key("stroke.width", on: items.map { "\($0)" }, drag: "\(propertyScrubSerial)")) { $0.width = width }
    }

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
    static let noStroke = Stroke(width: 0)

    /// The shape addresses the inspector paints, each with its shape.
    var paintShapes: [(StageAddress, FlareShape)] {
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

    /// One "Set Stroke" step: `change` applied to each shape's own stroke, so a field the set doesn't name stays. With
    /// `coalesceKey` it joins that key's open step; no group then, since a group ends coalescing.
    private mutating func editStroke(coalesceKey: String? = nil, _ change: (inout Stroke) -> Void) {
        let found = paintShapes
        guard !found.isEmpty else { return paintError = Self.noShape }
        var batches: [(Stroke, [StageAddress])] = [], keys: [PaintKeyWrite] = []
        for (address, shape) in found {
            let (stroke, keyed) = strokeEdit(address, shape, change)
            keys += keyed
            if !keyed.isEmpty, stroke == shape.stroke { continue }
            if let i = batches.firstIndex(where: { $0.0 == stroke }) { batches[i].1.append(address) }
            else { batches.append((stroke, [address])) }
        }
        let properties = services.properties
        let grouped = coalesceKey == nil && (batches.count > 1 || !keys.isEmpty)
        paintStep(grouped ? "Set Stroke" : nil) { engine in
            for (stroke, items) in batches {
                try properties.setStroke(stroke, of: items, coalesceKey: coalesceKey, in: &engine)
            }
            try properties.keyPaint(keys, coalesceKey: coalesceKey, in: &engine)
        }
    }

    /// Runs one undo step; a refusal lands in `paintError` too, and a success clears it.
    mutating func paintStep(_ label: String?, _ body: (inout CommandEngine) throws -> Void) {
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
