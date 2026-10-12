// HaloLayer.swift: one layer in a Halo composition: what kind it is, the frames
// it is visible for and its color. Linux-safe: no UI imports. Layers live in
// `HaloComposition.layers`, top first; HaloProject adds and selects them.

/// What a layer draws: a solid fill, a shape, text, or nothing (a null that
/// other layers can follow).
public enum HaloLayerKind: String, CaseIterable, Sendable {
    case solid, shape, text, null

    /// The kind's name as menus and default layer names show it ("Solid").
    public var title: String {
        switch self {
        case .solid: "Solid"
        case .shape: "Shape"
        case .text: "Text"
        case .null: "Null"
        }
    }

    /// The color a new layer of this kind starts with.
    public var defaultColor: HaloLayerColor {
        switch self {
        case .solid: HaloLayerColor(red: 0.85, green: 0.33, blue: 0.25)
        case .shape: HaloLayerColor(red: 0.25, green: 0.55, blue: 0.9)
        case .text: HaloLayerColor(red: 1, green: 1, blue: 1)
        case .null: HaloLayerColor(red: 0.6, green: 0.6, blue: 0.6)
        }
    }
}

/// An sRGB color with components in 0...1.
public struct HaloLayerColor: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// A layer, visible from `inFrame` up to (not including) `outFrame`.
public struct HaloLayer: Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var kind: HaloLayerKind
    public var inFrame: Int
    public var outFrame: Int
    public var color: HaloLayerColor

    public init(id: String, name: String, kind: HaloLayerKind, inFrame: Int, outFrame: Int, color: HaloLayerColor) {
        self.id = id
        self.name = name
        self.kind = kind
        self.inFrame = inFrame
        self.outFrame = outFrame
        self.color = color
    }
}
