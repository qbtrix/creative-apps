// LayerStyle.swift (layer-styles LS-1): the suite's one layer style, eight effects plus fill opacity. Colours are
// the kernel's `FillColor` (sRGB, straight alpha), gradients its `Fill`; `BlendMode`, `StrokePosition`, `BevelShape`
// and `BevelTechnique` are CoreRaster's, so there is no second copy. Linux-safe.
import CoreRaster
import SuiteKernel

/// The eight styles; the panel lists them in this order. Paint order is `StyleRules.paintOrder`.
public enum StyleKind: String, Codable, CaseIterable, Sendable {
    case dropShadow, innerShadow, outerGlow, innerGlow, stroke, colorOverlay, gradientOverlay, bevel
}

/// A drop or inner shadow: `angle` in degrees (0 right, 90 down), px for the rest, `spread` 0...1.
public struct StyleShadow: Hashable, Codable, Sendable {
    public var color: FillColor; public var angle, distance, spread, size: Double
    public init(color: FillColor, angle: Double, distance: Double, spread: Double, size: Double) {
        (self.color, self.angle, self.distance, self.spread, self.size) = (color, angle, distance, spread, size)
    }
}

/// An outer or inner glow: `spread` 0...1, `size` px.
public struct StyleGlow: Hashable, Codable, Sendable {
    public var color: FillColor; public var spread, size: Double
    public init(color: FillColor, spread: Double, size: Double) { (self.color, self.spread, self.size) = (color, spread, size) }
}

/// A stroke round the layer's edge: a solid or gradient fill, `size` px, inside, outside or centred.
public struct StyleStroke: Hashable, Codable, Sendable {
    public var fill: Fill; public var size: Double; public var position: StrokePosition
    public init(fill: Fill, size: Double, position: StrokePosition) { (self.fill, self.size, self.position) = (fill, size, position) }
}

/// A fill over the layer's alpha: solid for a colour overlay, linear or radial for a gradient overlay.
public struct StyleOverlay: Hashable, Codable, Sendable {
    public var fill: Fill
    public init(fill: Fill) { self.fill = fill }
}

/// A bevel and emboss: shape and profile, depth (1 is 100%), px sizes, the light's angle and
/// altitude in degrees, and the highlight and shadow layers' colour, blend mode and opacity.
public struct StyleBevel: Hashable, Codable, Sendable {
    public var shape: BevelShape, technique: BevelTechnique
    public var depth: Double, up: Bool, size: Double, soften: Double, angle: Double, altitude: Double
    public var highlight: FillColor, highlightBlend: BlendMode, highlightOpacity: Double
    public var shadow: FillColor, shadowBlend: BlendMode, shadowOpacity: Double
    public init(shape: BevelShape, technique: BevelTechnique, depth: Double, up: Bool, size: Double, soften: Double,
                angle: Double, altitude: Double, highlight: FillColor, highlightBlend: BlendMode, highlightOpacity: Double,
                shadow: FillColor, shadowBlend: BlendMode, shadowOpacity: Double) {
        (self.shape, self.technique, self.depth, self.up, self.size, self.soften) = (shape, technique, depth, up, size, soften)
        (self.angle, self.altitude) = (angle, altitude)
        (self.highlight, self.highlightBlend, self.highlightOpacity) = (highlight, highlightBlend, highlightOpacity)
        (self.shadow, self.shadowBlend, self.shadowOpacity) = (shadow, shadowBlend, shadowOpacity)
    }
}

/// One effect's parameters; the case matches the effect's kind (`StyleRules.check`).
public enum StyleParameters: Hashable, Codable, Sendable {
    case shadow(StyleShadow), glow(StyleGlow), stroke(StyleStroke), overlay(StyleOverlay), bevel(StyleBevel)
}

/// One effect: its kind, switch, blend mode, opacity 0...1 and parameters.
public struct StyleEffect: Hashable, Codable, Sendable {
    public var kind: StyleKind; public var isEnabled: Bool
    public var blendMode: BlendMode; public var opacity: Double
    public var parameters: StyleParameters
    public init(kind: StyleKind, isEnabled: Bool, blendMode: BlendMode, opacity: Double, parameters: StyleParameters) {
        (self.kind, self.isEnabled, self.blendMode, self.opacity, self.parameters) = (kind, isEnabled, blendMode, opacity, parameters)
    }
}

/// A layer's style: at most one effect per kind, plus the fill opacity (the layer's own pixels; effects keep theirs).
public struct LayerStyle: Hashable, Codable, Sendable {
    public var effects: [StyleEffect]; public var fillOpacity: Double
    public init(effects: [StyleEffect], fillOpacity: Double) { (self.effects, self.fillOpacity) = (effects, fillOpacity) }
    /// No effects at full fill opacity: a layer drawn as it is.
    public static let none = LayerStyle(effects: [], fillOpacity: 1)

    /// Whether drawing the style changes anything: an enabled effect, or fill opacity under 1.
    public var isVisible: Bool { effects.contains(where: \.isEnabled) || fillOpacity < 1 }

    /// The effect of `kind`, nil when the style has none.
    public func effect(_ kind: StyleKind) -> StyleEffect? { effects.first { $0.kind == kind } }
}
