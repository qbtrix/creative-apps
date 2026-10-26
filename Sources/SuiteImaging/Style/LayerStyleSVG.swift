// LayerStyleSVG.swift (layer-styles LS-1 stub, LS-7 body): a layer style as one SVG `<filter>`
// of W3C Filter Effects Level 1 primitives, with a warning for each style written approximately
// or not at all. Linux-safe.
//
// Angles follow `StyleProgram` (LS-8): the angle is the light's, y down, so the shadow falls away from it:
// (dx, dy) = distance × (−cos, sin), and 135° at 8 px is (5.66, 5.66), down and to the right. Each effect is its
// alpha mask painted by `painted` and composited onto what is under it by `feBlend` with its own mode; drop shadow,
// outer glow and an outside stroke go under the layer, the rest over it clipped to `SourceAlpha`.
#if canImport(Glibc)
import Glibc  // sin, cos
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster
import SuiteKernel

public enum LayerStyleSVG {
    /// The unit box a style's `Fill` points are in.
    static let unit = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)

    /// A `<filter>` for `style` on a shape whose box is `box`, and the styles it wrote approximately or not at all.
    /// The region is `box` grown by `StyleRules.reach` on every side; "" and no warnings when nothing is visible.
    public static func filter(_ style: LayerStyle, id: String, box: Rect) -> (svg: String, warnings: [String]) {
        let style = StyleRules.clamped(style)
        guard style.isVisible else { return ("", []) }
        let effects = StyleRules.paintOrder.compactMap(style.effect).filter(\.isEnabled)
        var writer = Writer(id: id, box: box)
        var backdrop = writer.add("feFlood", #"flood-opacity="0""#)
        for effect in effects where isUnder(effect) { backdrop = writer.composite(effect, over: backdrop) }
        let layer = style.fillOpacity < 1
            ? writer.add("feComponentTransfer", #"in="SourceGraphic""#, children: slope(style.fillOpacity)) : "SourceGraphic"
        backdrop = writer.blend(layer, over: backdrop, .normal, "layer")
        for effect in effects where !isUnder(effect) { backdrop = writer.composite(effect, over: backdrop) }
        let pad = Double(StyleRules.reach(style)), n = number
        let open = #"<filter id="\#(id)" filterUnits="userSpaceOnUse" x="\#(n(box.minX - pad))" y="\#(n(box.minY - pad))" "#
            + #"width="\#(n(box.width + 2 * pad))" height="\#(n(box.height + 2 * pad))" color-interpolation-filters="sRGB">"#
        return (open + writer.body + "</filter>", writer.warnings)
    }

    /// Drawn under the layer: drop shadow, outer glow and an outside stroke (`StyleRules.paintOrder`'s note).
    static func isUnder(_ effect: StyleEffect) -> Bool {
        if case .stroke(let s) = effect.parameters { return s.position == .outside }
        return effect.kind == .dropShadow || effect.kind == .outerGlow
    }

    /// SVG 1.1's `feBlend` modes; the rest are Filter Effects Level 1 keywords an SVG 1.1 viewer draws as normal.
    static let svg11: Set<BlendMode> = [.normal, .multiply, .screen, .darken, .lighten]

    /// `colorDodge` as "color dodge", the words a warning names.
    static func words(_ name: String) -> [String] {
        var out = [""]
        for ch in name {
            if ch.isUppercase { out.append(ch.lowercased()) } else { out[out.count - 1].append(ch) }
        }
        return out
    }

    /// `value` rounded to 2 decimals, a whole number without ".0"; "0" when not finite.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        let rounded = (value * 100).rounded() / 100
        if rounded == 0 { return "0" }
        return rounded == rounded.rounded() && abs(rounded) < 1e15 ? String(Int(rounded)) : String(rounded)
    }

    /// An `feFuncA` that scales alpha by `factor`.
    static func slope(_ factor: Double) -> String { #"<feFuncA type="linear" slope="\#(number(factor))"/>"# }

    /// SVG markup made safe for a quoted `data:` URI attribute: XML escapes, and `#` as `%23` so it isn't a fragment.
    static func escaped(_ markup: String) -> String {
        var out = ""
        for ch in markup {
            switch ch {
            case "&": out += "&amp;"
            case "\"": out += "&quot;"
            case "<": out += "&lt;"
            case "#": out += "%23"
            default: out.append(ch)
            }
        }
        return out
    }

    /// The primitives written so far, numbered `<id>-<n>`, and the warnings, each once.
    struct Writer {
        let id: String, box: Rect
        var body = "", warnings: [String] = [], count = 0

        /// Appends one primitive and returns its result name.
        mutating func add(_ element: String, _ attributes: String, children: String = "") -> String {
            count += 1
            let result = "\(id)-\(count)", open = "<\(element) \(attributes) result=\"\(result)\""
            body += children.isEmpty ? open + "/>" : open + ">" + children + "</\(element)>"
            return result
        }

        mutating func warn(_ warning: String) { if !warnings.contains(warning) { warnings.append(warning) } }

        /// `source` over `backdrop` in `mode`, warning when the mode is past SVG 1.1's five.
        mutating func blend(_ source: String, over backdrop: String, _ mode: BlendMode, _ what: String) -> String {
            let name = LayerStyleSVG.words(mode.rawValue)
            if !LayerStyleSVG.svg11.contains(mode) {
                warn("The \(what) blends in \(name.joined(separator: " ")), a Filter Effects Level 1 mode SVG 1.1 viewers draw as normal.")
            }
            return add("feBlend", #"in="\#(source)" in2="\#(backdrop)" mode="\#(name.joined(separator: "-"))""#)
        }

        /// `effect` drawn and blended onto `backdrop`; returns the new backdrop.
        mutating func composite(_ effect: StyleEffect, over backdrop: String) -> String {
            let what = LayerStyleSVG.words(effect.kind.rawValue).joined(separator: " ")
            var backdrop = backdrop
            for (result, mode) in draw(effect) { backdrop = blend(result, over: backdrop, mode, what) }
            return backdrop
        }

        mutating func morph(_ input: String, _ op: String, _ radius: Double) -> String {
            add("feMorphology", #"in="\#(input)" operator="\#(op)" radius="\#(LayerStyleSVG.number(radius))""#)
        }

        mutating func clip(_ input: String, _ op: String = "in", to mask: String = "SourceAlpha") -> String {
            add("feComposite", #"in="\#(input)" in2="\#(mask)" operator="\#(op)""#)
        }

        /// The alpha outside the shape, for the inner shadow and glow.
        mutating func inverted() -> String {
            add("feComponentTransfer", #"in="SourceAlpha""#, children: #"<feFuncA type="table" tableValues="1 0"/>"#)
        }

        /// The effect's coloured results, each with the mode it blends in.
        mutating func draw(_ e: StyleEffect) -> [(String, BlendMode)] {
            let n = LayerStyleSVG.number
            switch e.parameters {
            case .shadow(let s):
                let inner = e.kind == .innerShadow
                var mask = inner ? inverted() : "SourceAlpha"
                if s.spread > 0 { mask = morph(mask, "dilate", s.size * s.spread) }
                mask = add("feGaussianBlur", #"in="\#(mask)" stdDeviation="\#(n(s.size / 3))""#)
                let radians = s.angle * .pi / 180
                mask = add("feOffset", #"in="\#(mask)" dx="\#(n(-s.distance * cos(radians)))" dy="\#(n(s.distance * sin(radians)))""#)
                return [(painted(.solid(s.color), opacity: e.opacity, mask: inner ? clip(mask) : mask), e.blendMode)]
            case .glow(let g):
                let inner = e.kind == .innerGlow
                var mask = inner ? inverted() : "SourceAlpha"
                if g.spread > 0 { mask = morph(mask, "dilate", g.size * g.spread) }
                mask = add("feGaussianBlur", #"in="\#(mask)" stdDeviation="\#(n(g.size / 3))""#)
                return [(painted(.solid(g.color), opacity: e.opacity, mask: inner ? clip(mask) : mask), e.blendMode)]
            case .stroke(let s):
                warn("The stroke's corners are square in SVG.")
                let ring: String
                switch s.position {
                case .outside: ring = clip(morph("SourceAlpha", "dilate", s.size), "out")
                case .inside: ring = clip("SourceAlpha", "out", to: morph("SourceAlpha", "erode", s.size))
                case .center:
                    let inner = morph("SourceAlpha", "erode", s.size / 2)
                    ring = clip(morph("SourceAlpha", "dilate", s.size / 2), "out", to: inner)
                }
                return [(painted(s.fill, opacity: e.opacity, mask: ring), e.blendMode)]
            case .overlay(let o):
                return [(painted(o.fill, opacity: e.opacity, mask: "SourceAlpha"), e.blendMode)]
            case .bevel(let b):
                warn("The bevel is approximated in SVG by distant lights on the blurred edge.")
                let bump = add("feGaussianBlur", #"in="SourceAlpha" stdDeviation="\#(n((b.size + b.soften) / 3))""#)
                let azimuth = (b.up ? 360 - b.angle : 540 - b.angle).truncatingRemainder(dividingBy: 360)
                let light = { (color: FillColor) in
                    #"in="\#(bump)" surfaceScale="\#(n(b.depth * b.size / 2))" specularConstant="1" specularExponent="20" "#
                        + #"lighting-color="\#(SampleRules.hex(color).lowercased())""#
                }
                let source = { (azimuth: Double) in
                    #"<feDistantLight azimuth="\#(n(azimuth))" elevation="\#(n(b.altitude))"/>"#
                }
                var out: [(String, BlendMode)] = []
                for (color, turn, opacity, mode) in [(b.highlight, 0.0, b.highlightOpacity, b.highlightBlend),
                                                     (b.shadow, 180.0, b.shadowOpacity, b.shadowBlend)] {
                    let toward = (azimuth + turn).truncatingRemainder(dividingBy: 360)
                    var lit = clip(add("feSpecularLighting", light(color), children: source(toward)))
                    if opacity * e.opacity < 1 { lit = add("feComponentTransfer", #"in="\#(lit)""#, children: LayerStyleSVG.slope(opacity * e.opacity)) }
                    out.append((lit, mode))
                }
                return out
            }
        }

        /// `fill` at `opacity` inside `mask`: a flood for a solid, an image of the box filled by
        /// `GradientSVG.definition` for a gradient, its unit-box points mapped to `box`.
        mutating func painted(_ fill: Fill, opacity: Double, mask: String) -> String {
            let n = LayerStyleSVG.number
            if case .solid(let c) = fill {
                let alpha = c.a.isNaN ? 0 : min(max(c.a, 0), 1)
                let flood = add("feFlood", #"flood-color="\#(SampleRules.hex(c).lowercased())" flood-opacity="\#(n(alpha * opacity))""#)
                return clip(flood, to: mask)
            }
            let gradient = "\(id)-gradient", (x, y, w, h) = (n(box.minX), n(box.minY), n(box.width), n(box.height))
            let image = #"<svg xmlns="http://www.w3.org/2000/svg" viewBox="\#(x) \#(y) \#(w) \#(h)" preserveAspectRatio="none">"#
                + GradientSVG.definition(GradientRules.mapped(fill, from: LayerStyleSVG.unit, to: box), id: gradient)
                + #"<rect x="\#(x)" y="\#(y)" width="\#(w)" height="\#(h)" fill="url(#\#(gradient))"/></svg>"#
            let placed = add("feImage", #"x="\#(x)" y="\#(y)" width="\#(w)" height="\#(h)" preserveAspectRatio="none" "#
                + #"href="data:image/svg+xml;utf8,\#(LayerStyleSVG.escaped(image))""#)
            let clipped = clip(placed, to: mask)
            return opacity < 1 ? add("feComponentTransfer", #"in="\#(clipped)""#, children: LayerStyleSVG.slope(opacity)) : clipped
        }
    }
}
