// HaloLayer.swift: one layer in a Halo composition: what kind it is, the
// frames it is visible for, its color, opacity, blend mode, the rectangle a
// solid fills, its keyframe tracks, the layer it follows, a text layer's
// words, a solid's or shape's gradient (gradient-fill HG-1), a shape
// layer's ShapeSpec (shape-tools HS-1), its stroke (stroke-style HK-1) and a
// solid's placed picture and focus (placed-images PH-1). Codable; decoding goes through the clamping init. Linux-safe: no UI imports. Layers live in `HaloComposition.layers`,
// top first; HaloProject adds and selects them. `blendMode` is CoreRaster's
// BlendMode, never a mirror of it.
import CoreRaster
import FlareCore
import SuiteKernel

/// What a layer draws: a solid fill, a shape, text, or nothing (a null that
/// other layers can follow).
public enum HaloLayerKind: String, CaseIterable, Codable, Sendable {
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

    /// The color a new layer of this kind starts with. Text starts near-black
    /// so new words read on the white artboard (#2176).
    public var defaultColor: HaloLayerColor {
        switch self {
        case .solid: HaloLayerColor(red: 0.85, green: 0.33, blue: 0.25)
        case .shape: HaloLayerColor(red: 0.25, green: 0.55, blue: 0.9)
        case .text: HaloLayerColor(red: 0.1, green: 0.1, blue: 0.1)
        case .null: HaloLayerColor(red: 0.6, green: 0.6, blue: 0.6)
        }
    }
}

/// An sRGB color with components in 0...1.
public struct HaloLayerColor: Codable, Sendable, Hashable {
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
public struct HaloLayerRect: Codable, Sendable, Hashable {
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
public struct HaloLayer: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var kind: HaloLayerKind
    public var inFrame: Int
    public var outFrame: Int
    public var color: HaloLayerColor
    /// 0 (transparent) to 1 (opaque). Every assignment, the init's included,
    /// clamps it to 0...1, and a NaN falls back to 1, the default.
    public var opacity: Double {
        get { storedOpacity }
        set { storedOpacity = Self.clampedOpacity(newValue) }
    }
    private var storedOpacity: Double
    public var blendMode: BlendMode
    /// The area a solid fills, in composition pixels; nil fills the whole frame.
    public var rect: HaloLayerRect?
    /// W0: keyframe tracks by `HaloProperty.rawValue`, each sorted by frame
    /// with one key per frame. A property with no track uses its default.
    public var tracks: [String: [HaloKeyframe]] = [:]
    /// W0: the layer this one follows; nil for none. Never a cycle.
    public var parentID: String?
    /// W0: a text layer's words and size; nil for other kinds (tier 2, #430).
    public var text: HaloTextContent?
    /// HG-1: the layer's gradient, its points in a unit box (0...1 across the
    /// layer's bounds); nil fills `color`. Coded under "gradient" only when set.
    public var gradient: Fill?
    /// HS-1: what a shape layer draws in its box (a star's points, a
    /// polygon's sides); nil draws the ellipse. Coded under "shape" only when set.
    public var shape: ShapeSpec?
    /// HK-1: a shape layer's outline, the kernel's VectorStroke; nil draws
    /// none. Coded under "stroke" only when set.
    public var stroke: VectorStroke?
    /// PH-1: a solid's picture, the kernel's PlacedAsset, drawn into the
    /// solid's box; nil fills `color`. Coded under "placedAsset" only when set.
    public var placedAsset: PlacedAsset?
    /// PH-1: the picture's point (0...1 across it) kept in view when it
    /// covers the box. The kernel's default, the centre, is coded as nothing.
    public var placedFocus: Point {
        get { storedPlacedFocus ?? Self.defaultPlacedFocus }
        set { storedPlacedFocus = newValue == Self.defaultPlacedFocus ? nil : newValue }
    }
    private var storedPlacedFocus: Point?
    /// The kernel's default focus in `PlacedImage`, the picture's centre.
    static let defaultPlacedFocus = Point(x: 0.5, y: 0.5)

    enum CodingKeys: String, CodingKey {
        case id, name, kind, inFrame, outFrame, color, storedOpacity = "opacity", blendMode, rect, tracks, parentID, text, gradient, shape, stroke, placedAsset
        case storedPlacedFocus = "placedFocus"
    }

    /// Decodes through the clamping init, so a file can't carry an opacity
    /// outside 0...1 or NaN. Missing W0 fields decode as empty.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
            kind: try c.decode(HaloLayerKind.self, forKey: .kind), inFrame: try c.decode(Int.self, forKey: .inFrame),
            outFrame: try c.decode(Int.self, forKey: .outFrame), color: try c.decode(HaloLayerColor.self, forKey: .color),
            opacity: try c.decode(Double.self, forKey: .storedOpacity),
            blendMode: try c.decode(BlendMode.self, forKey: .blendMode),
            rect: try c.decodeIfPresent(HaloLayerRect.self, forKey: .rect))
        tracks = try c.decodeIfPresent([String: [HaloKeyframe]].self, forKey: .tracks) ?? [:]
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID)
        text = try c.decodeIfPresent(HaloTextContent.self, forKey: .text)
        gradient = try c.decodeIfPresent(Fill.self, forKey: .gradient)
        shape = try c.decodeIfPresent(ShapeSpec.self, forKey: .shape)
        stroke = try c.decodeIfPresent(VectorStroke.self, forKey: .stroke)
        placedAsset = try c.decodeIfPresent(PlacedAsset.self, forKey: .placedAsset)
        placedFocus = try c.decodeIfPresent(Point.self, forKey: .storedPlacedFocus) ?? Self.defaultPlacedFocus
    }

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
        self.storedOpacity = Self.clampedOpacity(opacity)
        self.blendMode = blendMode
        self.rect = rect
    }

    /// `value` in 0...1; NaN becomes 1, so a bad value never hides the layer.
    static func clampedOpacity(_ value: Double) -> Double { value.isNaN ? 1 : min(max(value, 0), 1) }

    /// Whether the layer shows at `frame`: from `inFrame` up to, not including, `outFrame`.
    public func isVisible(at frame: Int) -> Bool { frame >= inFrame && frame < outFrame }

    /// This layer under another id, everything else kept.
    func withID(_ id: String) -> HaloLayer {
        var copy = HaloLayer(
            id: id, name: name, kind: kind, inFrame: inFrame, outFrame: outFrame, color: color, opacity: opacity,
            blendMode: blendMode, rect: rect)
        copy.tracks = tracks
        copy.parentID = parentID  // W0: duplicateComposition remaps it to the copy's ids
        copy.text = text
        copy.gradient = gradient
        copy.shape = shape
        copy.stroke = stroke
        copy.placedAsset = placedAsset
        copy.placedFocus = placedFocus
        return copy
    }
}
