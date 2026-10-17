// HaloTextEdits+Color.swift (TX-2): the inspector's color row. A text, solid
// or shape layer's color is one "Change Color" step through `edit`, and the
// picks in a row merge into it (the system color panel sends a stream with no
// end event); a null takes no color. Components clamp to 0...1 and a NaN pick
// is ignored. The row shows and sends 8-bit sRGB through `bytes`.
// Linux-safe: no UI imports.

extension HaloLayerColor {
    /// The color of 8-bit sRGB components, each divided by 255.
    public init(bytes red: UInt8, _ green: UInt8, _ blue: UInt8) {
        self.init(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// The 8-bit sRGB components: each clamped to 0...1 (a NaN reads 0), times
    /// 255, rounded. The same rule `linearPixel` decodes for the renderer.
    public var bytes: (red: UInt8, green: UInt8, blue: UInt8) {
        func byte(_ v: Double) -> UInt8 { UInt8(((v.isNaN ? 0 : min(max(v, 0), 1)) * 255).rounded()) }
        return (byte(red), byte(green), byte(blue))
    }

    /// Every component in 0...1; nil when one is NaN.
    var clampedToUnit: HaloLayerColor? {
        let parts = [red, green, blue]
        guard !parts.contains(where: \.isNaN) else { return nil }
        let c = parts.map { min(max($0, 0), 1) }
        return HaloLayerColor(red: c[0], green: c[1], blue: c[2])
    }
}

extension HaloProject {
    /// The color row's identifier, where a color refusal shows.
    static let layerColorControl = "halo.inspector.text.color"

    /// The selected layer's color; nil with no layer selected or on a null,
    /// which takes no color.
    public var selectedLayerColor: HaloLayerColor? {
        guard let layer = selectedLayer, layer.kind != .null else { return nil }
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
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID }) else {
                throw HaloEditError.noComposition
            }
            guard let l = doc.compositions[c].layers.firstIndex(where: { $0.id == doc.selectedLayerID }) else {
                throw HaloEditError.noLayerSelected
            }
            guard doc.compositions[c].layers[l].kind != .null else { return }
            doc.compositions[c].layers[l].color = clamped
        }
    }
}
