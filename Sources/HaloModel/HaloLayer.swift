// HaloLayer.swift: one layer in a Halo composition: what kind it is, the frames
// it is visible for, its color, opacity, blend mode and the rectangle a solid
// fills. Linux-safe: no UI imports. Layers live in `HaloComposition.layers`,
// top first; HaloProject adds and selects them. `blendMode` is CoreRaster's
// BlendMode, never a mirror of it.
import CoreRaster

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

/// An axis-aligned rectangle in composition pixels, top-left origin.
public struct HaloLayerRect: Sendable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
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
    /// 0 (transparent) to 1 (opaque); the init clamps it.
    public var opacity: Double
    public var blendMode: BlendMode
    /// The area a solid fills, in composition pixels; nil fills the whole frame.
    public var rect: HaloLayerRect?

    /// Clamps `opacity` to 0...1; a NaN opacity falls back to 1, the default.
    public init(
        id: String, name: String, kind: HaloLayerKind, inFrame: Int, outFrame: Int, color: HaloLayerColor,
        opacity: Double = 1, blendMode: BlendMode = .normal, rect: HaloLayerRect? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.inFrame = inFrame
        self.outFrame = outFrame
        self.color = color
        self.opacity = opacity.isNaN ? 1 : min(max(opacity, 0), 1)
        self.blendMode = blendMode
        self.rect = rect
    }

    /// Whether the layer shows at `frame`: from `inFrame` up to, not including, `outFrame`.
    public func isVisible(at frame: Int) -> Bool { frame >= inFrame && frame < outFrame }

    /// This layer under another id, everything else kept.
    func withID(_ id: String) -> HaloLayer {
        HaloLayer(
            id: id, name: name, kind: kind, inFrame: inFrame, outFrame: outFrame, color: color, opacity: opacity,
            blendMode: blendMode, rect: rect)
    }
}
