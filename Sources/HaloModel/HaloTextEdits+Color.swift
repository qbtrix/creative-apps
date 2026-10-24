// HaloTextEdits+Color.swift (TX-2): the inspector's color row. A text, solid
// or shape layer's color is one "Change Color" step through `edit`, and the
// picks in a row merge into it (the system color panel sends a stream with no
// end event); a null takes no color. Components clamp to 0...1 and a NaN pick
// is ignored. The row shows and sends 8-bit sRGB through `bytes`.
// Linux-safe: no UI imports.
import SuiteKernel

extension HaloLayerColor {
    /// The color of 8-bit sRGB components, each divided by 255.
    public init(bytes red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.init(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// The 8-bit sRGB components: HexText's rounding, each clamped to 0...1,
    /// times 255, rounded (a NaN or an infinity reads 0).
    public var bytes: (red: UInt8, green: UInt8, blue: UInt8) {
        (HexText.byte(red), HexText.byte(green), HexText.byte(blue))
    }

    /// The kernel's colour as Halo's (both sRGB 0...1), its alpha dropped: a layer's colour has no alpha.
    public init(_ fill: FillColor) { self.init(red: fill.r, green: fill.g, blue: fill.b) }

    /// This colour as the kernel's FillColor, opaque.
    public var fill: FillColor { FillColor(r: red, g: green, b: blue) }

    /// Every component in 0...1; nil when one is NaN.
    var clampedToUnit: HaloLayerColor? {
        let parts = [red, green, blue]
        guard !parts.contains(where: \.isNaN) else { return nil }
        let c = parts.map { min(max($0, 0), 1) }
        return HaloLayerColor(red: c[0], green: c[1], blue: c[2])
    }
}

extension HaloLayerKind {
    /// Whether `setLayerColor` can color a layer of this kind: every kind but
    /// a null. The color row's availability asks the same question.
    var takesColor: Bool { self != .null }
}

extension HaloProject {
    /// The color row's identifier, where a color refusal shows.
    static let layerColorControl = "halo.inspector.text.color"

    /// The selected layer's color; nil with no layer selected or on a null,
    /// which takes no color.
    public var selectedLayerColor: HaloLayerColor? {
        guard let layer = selectedLayer, layer.kind.takesColor else { return nil }
        return layer.color
    }

    /// Sets the selected text, solid or shape layer's color, each component
    /// clamped to 0...1. One step, "Change Color"; consecutive picks on one
    /// layer merge into it. A NaN component, a null or the same color change
    /// nothing and record nothing. Refused with `.noComposition` or
    /// `.noLayerSelected` under the color row.
    public mutating func setLayerColor(_ color: HaloLayerColor) {
        guard let clamped = color.clampedToUnit else { return }
        let key = selectedLayerID.map { "\($0).color" }
        edit("Change Color", control: Self.layerColorControl, coalesceKey: key) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            guard doc.compositions[c].layers[l].kind.takesColor else { return }
            doc.compositions[c].layers[l].color = clamped
        }
    }
}
