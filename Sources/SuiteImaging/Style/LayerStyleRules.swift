// LayerStyleRules.swift (layer-styles LS-1 stubs, LS-5 bodies): ranges, defaults, one effect per kind, paint order,
// reach, presets and the JSON `style.copy` returns and `style.paste` takes. An effect's JSON is flat: `kind`,
// `enabled`, `blend`, `opacity` and its parameters under the same keys `style.set`'s patch uses, so decoding is
// defaults plus a patch. A non-finite number is refused (`CatalogError.malformedParams` naming the field), never
// clamped. Linux-safe.
import CoreRaster
import SuiteKernel

public enum StyleRules {
    /// The why-not every style command shows when nothing stylable is selected.
    public static let noLayerHelp = "Select a layer to style."
    /// What a `style.*` run throws until LS-6 fills the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "style", feature: "layer-styles LS-6")

    /// Each number's range (px unless noted); angles wrap to [0, 360) instead.
    public static let unitRange: ClosedRange<Double> = 0...1  // opacity, fill opacity, spread
    public static let distanceRange: ClosedRange<Double> = 0...1000
    public static let sizeRange: ClosedRange<Double> = 0...250
    public static let strokeSizeRange: ClosedRange<Double> = 1...250
    public static let depthRange: ClosedRange<Double> = 0.01...10  // 1 is 100%
    public static let softenRange: ClosedRange<Double> = 0...16
    public static let altitudeRange: ClosedRange<Double> = 0...90  // degrees

    /// Under the layer, then over it, the stroke last (core's `stroked` puts an outside stroke under the layer).
    public static let paintOrder: [StyleKind] = [.dropShadow, .outerGlow, .gradientOverlay, .colorOverlay, .innerGlow,
                                                 .innerShadow, .bevel, .stroke]

    /// `kind`'s defaults, turned on.
    public static func defaults(_ kind: StyleKind) -> StyleEffect {
        let unit = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)
        let (parameters, blend, opacity): (StyleParameters, BlendMode, Double)
        switch kind {
        case .dropShadow: (parameters, blend, opacity) = (.shadow(StyleShadow(color: .black, angle: 135, distance: 8, spread: 0, size: 12)), .multiply, 0.35)
        case .innerShadow: (parameters, blend, opacity) = (.shadow(StyleShadow(color: .black, angle: 135, distance: 4, spread: 0, size: 6)), .multiply, 0.5)
        case .outerGlow: (parameters, blend, opacity) = (.glow(StyleGlow(color: .white, spread: 0, size: 12)), .screen, 0.6)
        case .innerGlow: (parameters, blend, opacity) = (.glow(StyleGlow(color: .white, spread: 0, size: 8)), .screen, 0.5)
        case .stroke: (parameters, blend, opacity) = (.stroke(StyleStroke(fill: .solid(.black), size: 2, position: .outside)), .normal, 1)
        case .colorOverlay: (parameters, blend, opacity) = (.overlay(StyleOverlay(fill: .solid(FillColor(r: 1, g: 0, b: 0)))), .normal, 1)
        case .gradientOverlay:
            let ramp = GradientRules.rotated(GradientRules.converted(.solid(.black), to: .linear, in: unit), to: 90, in: unit)
            (parameters, blend, opacity) = (.overlay(StyleOverlay(fill: ramp)), .normal, 1)
        case .bevel:
            (parameters, blend, opacity) = (.bevel(StyleBevel(shape: .innerBevel, technique: .smooth, depth: 1, up: true, size: 6, soften: 0,
                                                              angle: 120, altitude: 30, highlight: .white, highlightBlend: .screen,
                                                              highlightOpacity: 0.75, shadow: .black, shadowBlend: .multiply,
                                                              shadowOpacity: 0.75)), .normal, 1)
        }
        return StyleEffect(kind: kind, isEnabled: true, blendMode: blend, opacity: opacity, parameters: parameters)
    }

    /// Every number in its range and every angle in [0, 360); a non-finite value is left for `check` to name.
    public static func clamped(_ style: LayerStyle) -> LayerStyle {
        LayerStyle(effects: style.effects.map(clamped), fillOpacity: clamp(style.fillOpacity, unitRange))
    }

    /// `effect` with its numbers in range.
    static func clamped(_ effect: StyleEffect) -> StyleEffect {
        var e = effect
        e.opacity = clamp(e.opacity, unitRange)
        switch e.parameters {
        case .shadow(var s):
            (s.angle, s.distance) = (wrapped(s.angle), clamp(s.distance, distanceRange))
            (s.spread, s.size) = (clamp(s.spread, unitRange), clamp(s.size, sizeRange))
            e.parameters = .shadow(s)
        case .glow(var g): (g.spread, g.size) = (clamp(g.spread, unitRange), clamp(g.size, sizeRange)); e.parameters = .glow(g)
        case .stroke(var s): s.size = clamp(s.size, strokeSizeRange); e.parameters = .stroke(s)
        case .overlay: break
        case .bevel(var b):
            (b.depth, b.size, b.soften) = (clamp(b.depth, depthRange), clamp(b.size, sizeRange), clamp(b.soften, softenRange))
            (b.angle, b.altitude) = (wrapped(b.angle), clamp(b.altitude, altitudeRange))
            (b.highlightOpacity, b.shadowOpacity) = (clamp(b.highlightOpacity, unitRange), clamp(b.shadowOpacity, unitRange))
            e.parameters = .bevel(b)
        }
        return e
    }

    static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : value
    }

    static func wrapped(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return degrees }
        let turned = degrees.truncatingRemainder(dividingBy: 360)
        let positive = turned < 0 ? turned + 360 : turned
        return positive >= 360 ? 0 : positive
    }

    /// Why a decoded style is malformed, nil when fine: a second effect of a kind, parameters of another kind, or a
    /// number that isn't finite. Each reason names the kind.
    public static func check(_ style: LayerStyle) -> String? {
        var seen = Set<StyleKind>()
        for effect in style.effects {
            let name = effect.kind.rawValue
            guard seen.insert(effect.kind).inserted else { return "A second \(name) is ignored; a style holds one of each kind." }
            guard fits(effect) else { return "The \(name) holds another kind's parameters." }
            guard numbers(effect).allSatisfy(\.isFinite) else { return "The \(name) has a value that is not a finite number." }
        }
        return style.fillOpacity.isFinite ? nil : "The fill opacity is not a finite number."
    }

    static func fits(_ effect: StyleEffect) -> Bool {
        switch (effect.kind, effect.parameters) {
        case (.dropShadow, .shadow), (.innerShadow, .shadow), (.outerGlow, .glow), (.innerGlow, .glow), (.stroke, .stroke),
             (.colorOverlay, .overlay), (.gradientOverlay, .overlay), (.bevel, .bevel): true
        default: false
        }
    }

    static func numbers(_ effect: StyleEffect) -> [Double] {
        let channels = { (c: FillColor) in [c.r, c.g, c.b, c.a] }
        switch effect.parameters {
        case .shadow(let s): return [effect.opacity, s.angle, s.distance, s.spread, s.size] + channels(s.color)
        case .glow(let g): return [effect.opacity, g.spread, g.size] + channels(g.color)
        case .stroke(let s): return [effect.opacity, s.size]
        case .overlay: return [effect.opacity]
        case .bevel(let b):
            return [effect.opacity, b.depth, b.size, b.soften, b.angle, b.altitude, b.highlightOpacity, b.shadowOpacity]
                + channels(b.highlight) + channels(b.shadow)
        }
    }

    /// `style` with `kind`'s defaults on, replacing any effect of that kind.
    public static func adding(_ kind: StyleKind, to style: LayerStyle) -> LayerStyle {
        LayerStyle(effects: style.effects.filter { $0.kind != kind } + [defaults(kind)], fillOpacity: style.fillOpacity)
    }

    /// `style` with `patch` (`blend`, `opacity` and parameter fields) applied to `kind`'s effect, clamped;
    /// throws `malformedParams` naming the field on a non-finite or mistyped value, or when the style lacks `kind`.
    public static func setting(_ patch: JSONValue, on kind: StyleKind, in style: LayerStyle) throws -> LayerStyle {
        guard let index = style.effects.firstIndex(where: { $0.kind == kind }) else {
            throw malformed("/kind", "The layer has no \(kind.rawValue).")
        }
        var result = style
        result.effects[index] = try patched(style.effects[index], patch)
        return result
    }

    static func malformed(_ path: String, _ message: String) -> CatalogError {
        .malformedParams(id: "style", [SchemaIssue(path: path, message: message)])
    }

    /// `effect` with the fields `patch` names; other keys (`kind`, `enabled`, `drag`) are left to the caller.
    static func patched(_ effect: StyleEffect, _ patch: JSONValue) throws -> StyleEffect {
        guard case .object(let fields) = patch else { throw malformed("", "A style patch is an object.") }
        func number(_ key: String, _ value: inout Double) throws {
            guard let field = fields[key] else { return }
            guard case .number(let n) = field, n.isFinite else { throw malformed("/\(key)", "must be a finite number") }
            value = n
        }
        func named<T: RawRepresentable>(_ key: String, _ value: inout T) throws where T.RawValue == String {
            guard let field = fields[key] else { return }
            guard case .string(let raw) = field, let named = T(rawValue: raw) else { throw malformed("/\(key)", "is not a known name") }
            value = named
        }
        func color(_ key: String, _ value: inout FillColor) throws {
            guard let field = fields[key] else { return }
            guard case .object(let c) = field else { throw malformed("/\(key)", "must be a colour {r, g, b, a}") }
            var channels = [0.0, 0, 0, 1]
            for (i, name) in ["r", "g", "b", "a"].enumerated() where c[name] != nil || i < 3 {
                guard case .number(let n)? = c[name], n.isFinite else { throw malformed("/\(key)/\(name)", "must be a finite number") }
                channels[i] = n
            }
            value = FillColor(r: channels[0], g: channels[1], b: channels[2], a: channels[3])
        }
        func fill(_ value: inout Fill) throws {
            guard let field = fields["fill"] else { return }
            do { value = try field.decode(Fill.self) } catch { throw malformed("/fill", "must be a solid, linear or radial fill") }
        }
        var e = effect
        try named("blend", &e.blendMode); try number("opacity", &e.opacity)
        switch e.parameters {
        case .shadow(var s):
            try color("color", &s.color); try number("angle", &s.angle); try number("distance", &s.distance)
            try number("spread", &s.spread); try number("size", &s.size); e.parameters = .shadow(s)
        case .glow(var g): try color("color", &g.color); try number("spread", &g.spread); try number("size", &g.size); e.parameters = .glow(g)
        case .stroke(var s): try fill(&s.fill); try number("size", &s.size); try named("position", &s.position); e.parameters = .stroke(s)
        case .overlay(var o): try fill(&o.fill); e.parameters = .overlay(o)
        case .bevel(var b):
            try named("shape", &b.shape); try named("technique", &b.technique); try number("depth", &b.depth)
            if let up = fields["up"] { guard case .bool(let on) = up else { throw malformed("/up", "must be true or false") }; b.up = on }
            try number("size", &b.size); try number("soften", &b.soften); try number("angle", &b.angle); try number("altitude", &b.altitude)
            try color("highlight", &b.highlight); try named("highlightBlend", &b.highlightBlend); try number("highlightOpacity", &b.highlightOpacity)
            try color("shadow", &b.shadow); try named("shadowBlend", &b.shadowBlend); try number("shadowOpacity", &b.shadowOpacity)
            e.parameters = .bevel(b)
        }
        return clamped(e)
    }

    /// The px a renderer pads on each side: the most any enabled effect draws past the layer's edge, rounded up.
    public static func reach(_ style: LayerStyle) -> Int {
        let most = clamped(style).effects.filter(\.isEnabled).map { effect -> Double in
            switch effect.parameters {
            case .shadow(let s) where effect.kind == .dropShadow: s.distance + s.size * (1 + s.spread)
            case .glow(let g) where effect.kind == .outerGlow: g.size * (1 + g.spread)
            case .stroke(let s): s.position == .outside ? s.size : s.position == .center ? s.size / 2 : 0
            case .bevel(let b): b.shape == .innerBevel ? 0 : b.size
            default: 0
            }
        }.filter(\.isFinite).max() ?? 0
        return Int(most.rounded(.up))
    }

    /// Soft Shadow, Lifted, Outline, Neon, Embossed: our own values.
    public static let presets: [StylePreset] = [
        StylePreset(name: "Soft Shadow", style: preset([(.dropShadow, ["distance": .number(4), "size": .number(16), "opacity": .number(0.25)])])),
        StylePreset(name: "Lifted", style: preset([(.dropShadow, ["distance": .number(12), "size": .number(24), "spread": .number(0.1), "opacity": .number(0.3)])])),
        StylePreset(name: "Outline", style: preset([(.stroke, ["size": .number(3)])])),
        StylePreset(name: "Neon", style: preset([(.outerGlow, ["size": .number(18), "spread": .number(0.2), "opacity": .number(0.9), "color": cyan]),
                                                 (.innerGlow, ["size": .number(4), "opacity": .number(0.6), "color": cyan]),
                                                 (.stroke, ["size": .number(2), "fill": cyan])])),
        StylePreset(name: "Embossed", style: preset([(.bevel, ["shape": .string("emboss"), "size": .number(8), "depth": .number(1.5), "soften": .number(1)]),
                                                     (.dropShadow, ["distance": .number(2), "size": .number(4), "opacity": .number(0.2)])])),
    ]

    static let cyan = JSONValue.object(["r": .number(0), "g": .number(0.9), "b": .number(1), "a": .number(1)])

    static func preset(_ parts: [(StyleKind, [String: JSONValue])]) -> LayerStyle {
        LayerStyle(effects: parts.map { kind, patch in (try? patched(defaults(kind), .object(patch))) ?? defaults(kind) }, fillOpacity: 1)
    }

    /// The style as JSON: `{"effects": [...], "fillOpacity": n}`, each effect flat (see the header).
    public static func json(_ style: LayerStyle) -> JSONValue {
        .object(["effects": .array(style.effects.map(json)), "fillOpacity": .number(style.fillOpacity)])
    }

    static func json(_ e: StyleEffect) -> JSONValue {
        func color(_ c: FillColor) -> JSONValue { .object(["r": .number(c.r), "g": .number(c.g), "b": .number(c.b), "a": .number(c.a)]) }
        func fill(_ f: Fill) -> JSONValue { (try? JSONValue(encoding: f)) ?? .null }
        var more: [String: JSONValue]
        switch e.parameters {
        case .shadow(let s):
            more = ["color": color(s.color), "angle": .number(s.angle), "distance": .number(s.distance),
                    "spread": .number(s.spread), "size": .number(s.size)]
        case .glow(let g): more = ["color": color(g.color), "spread": .number(g.spread), "size": .number(g.size)]
        case .stroke(let s): more = ["fill": fill(s.fill), "size": .number(s.size), "position": .string(s.position.rawValue)]
        case .overlay(let o): more = ["fill": fill(o.fill)]
        case .bevel(let b):
            more = ["shape": .string(b.shape.rawValue), "technique": .string(b.technique.rawValue), "depth": .number(b.depth),
                    "up": .bool(b.up), "size": .number(b.size), "soften": .number(b.soften), "angle": .number(b.angle),
                    "altitude": .number(b.altitude), "highlight": color(b.highlight),
                    "highlightBlend": .string(b.highlightBlend.rawValue), "highlightOpacity": .number(b.highlightOpacity),
                    "shadow": color(b.shadow), "shadowBlend": .string(b.shadowBlend.rawValue), "shadowOpacity": .number(b.shadowOpacity)]
        }
        (more["kind"], more["enabled"], more["blend"], more["opacity"]) = (.string(e.kind.rawValue), .bool(e.isEnabled), .string(e.blendMode.rawValue), .number(e.opacity))
        return .object(more)
    }

    /// The style `json` holds, clamped, the first effect of each kind kept (`check` names the rest);
    /// throws `malformedParams` on an unknown kind or a non-finite or mistyped value.
    public static func style(json: JSONValue) throws -> LayerStyle {
        guard case .object(let root) = json, case .array(let list)? = root["effects"] else {
            throw malformed("/effects", "A style is {\"effects\": [...], \"fillOpacity\": n}.")
        }
        var effects: [StyleEffect] = []
        for (i, item) in list.enumerated() {
            guard case .object(let fields) = item, case .string(let raw)? = fields["kind"], let kind = StyleKind(rawValue: raw) else {
                throw malformed("/effects/\(i)/kind", "must be one of \(StyleKind.allCases.map(\.rawValue).joined(separator: ", "))")
            }
            guard !effects.contains(where: { $0.kind == kind }) else { continue }
            var effect = try patched(defaults(kind), item)
            if let on = fields["enabled"] { guard case .bool(let b) = on else { throw malformed("/effects/\(i)/enabled", "must be true or false") }; effect.isEnabled = b }
            effects.append(effect)
        }
        var fillOpacity = 1.0
        if let field = root["fillOpacity"] { guard case .number(let n) = field, n.isFinite else { throw malformed("/fillOpacity", "must be a finite number") }; fillOpacity = n }
        return LayerStyle(effects: effects, fillOpacity: clamp(fillOpacity, unitRange))
    }
}

/// A named built-in style.
public struct StylePreset: Hashable, Sendable {
    public var name: String; public var style: LayerStyle
    public init(name: String, style: LayerStyle) { (self.name, self.style) = (name, style) }
}
