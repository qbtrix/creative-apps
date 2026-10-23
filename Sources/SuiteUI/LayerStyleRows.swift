// LayerStyleRows.swift (layer-styles LS-2 placeholder, LS-3 rows): the selected style's rows in the right column of
// LayerStylePanel, and the words the panel shows. LS-3 gives each kind its rows (colour, blend, opacity, angle,
// distance, size, position, gradient, bevel), each sending one StyleIntent; a scrub shares one drag token (one undo
// step). A kind the layer doesn't have shows its defaults, disabled. LayerStylePanelTests drive the plain rules.
import Foundation
import SuiteImaging
import SuiteKernel
import SwiftUI

/// The panel's words and identifiers, outside any View so tests call them off the main actor.
public enum LayerStyleText {
    /// Why a control in the placeholder panel can't act yet.
    public static let pending = "Editing layer styles isn't in this build yet."

    /// A kind's name in the list; VoiceOver reads its switch as "<title>, on".
    public static func title(_ kind: StyleKind) -> String {
        switch kind {
        case .dropShadow: "Drop Shadow"
        case .innerShadow: "Inner Shadow"
        case .outerGlow: "Outer Glow"
        case .innerGlow: "Inner Glow"
        case .stroke: "Stroke"
        case .colorOverlay: "Color Overlay"
        case .gradientOverlay: "Gradient Overlay"
        case .bevel: "Bevel & Emboss"
        }
    }

    /// A kind's switch: `suite.style.toggle.<kind>`.
    public static func toggleID(_ kind: StyleKind) -> String { "suite.style.toggle.\(kind.rawValue)" }

    /// Why the switches can't act: the host's reason, no layer selected, or not built yet.
    public static func reason(style: LayerStyle?, help: String?) -> String {
        help ?? (style == nil ? StyleRules.noLayerHelp : pending)
    }
    /// Why no style control can act: the host's reason, or no layer selected; nil when they can.
    public static func blocked(style: LayerStyle?, help: String?) -> String? { help ?? (style == nil ? StyleRules.noLayerHelp : nil) }
    public static func off(_ kind: StyleKind) -> String { "Turn on \(title(kind)) to change it." }
    /// A raw value in words: "colorDodge" is "Color Dodge".
    public static func words(_ raw: String) -> String {
        raw.enumerated().reduce(into: "") { out, pair in
            out += pair.offset == 0 ? pair.element.uppercased() : (pair.element.isUppercase ? " " : "") + String(pair.element)
        }
    }
}

/// One row of a kind's settings: its `style.set` key, label and control. A slider shows the stored value times `scale`.
public struct StyleField: Hashable, Sendable {
    public enum Control: Hashable, Sendable {
        case color(FillColor), menu([String], selected: String), chips([String], selected: String), gradient(Fill)
        case number(shown: Double, range: ClosedRange<Double>, unit: String, scale: Double)
    }
    public let key: String, label: String, control: Control
    public var id: String { "suite.style.\(key)" }
    public var ids: [String] {
        if case .chips(let options, _) = control { return options.map { "\(id).\($0)" } }
        return isGradient ? [StyleEdit.gradientTypeID] : [id]
    }
    public var isGradient: Bool { if case .gradient = control { true } else { false } }
}

/// The rows each kind shows and the patch each edit sends.
public enum StyleEdit {
    public static let unit = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)
    static let gradientTypeID = "suite.style.gradient.type"

    public static func fields(_ effect: StyleEffect) -> [StyleField] {
        let modes = type(of: effect.blendMode).allCases.map(\.rawValue)
        var rows = [menu("blend", "Blend Mode", modes, effect.blendMode.rawValue), percent("opacity", "Opacity", effect.opacity)]
        switch effect.parameters {
        case .shadow(let s):
            rows += [color("color", "Color", s.color), number("angle", "Angle", s.angle, 0...360, "°"),
                     number("distance", "Distance", s.distance, 0...1000, "px"), percent("spread", "Spread", s.spread),
                     number("size", "Size", s.size, 0...250, "px")]
        case .glow(let g):
            rows += [color("color", "Color", g.color), percent("spread", "Spread", g.spread), number("size", "Size", g.size, 0...250, "px")]
        case .stroke(let s):
            let gradient = GradientRules.type(of: s.fill) != .solid
            rows += [number("size", "Size", s.size, 1...250, "px"),
                     chips("position", "Position", type(of: s.position).allCases.map(\.rawValue), s.position.rawValue),
                     chips("fill", "Fill", ["solid", "gradient"], gradient ? "gradient" : "solid"),
                     gradient ? StyleField(key: "gradient", label: "Gradient", control: .gradient(s.fill))
                         : color("color", "Color", GradientRules.color(of: s.fill, at: 0))]
        case .overlay(let o) where effect.kind == .gradientOverlay:
            let fill = GradientRules.type(of: o.fill) == .solid ? GradientRules.converted(o.fill, to: .linear, in: unit) : o.fill
            rows.append(StyleField(key: "gradient", label: "Gradient", control: .gradient(fill)))
        case .overlay(let o):
            rows.append(color("color", "Color", GradientRules.color(of: o.fill, at: 0)))
        case .bevel(let b):
            rows += [menu("shape", "Style", type(of: b.shape).allCases.map(\.rawValue), b.shape.rawValue),
                     menu("technique", "Technique", type(of: b.technique).allCases.map(\.rawValue), b.technique.rawValue),
                     number("depth", "Depth", b.depth, 1...1000, "%", 100),
                     chips("direction", "Direction", ["up", "down"], b.up ? "up" : "down"), number("size", "Size", b.size, 0...250, "px"),
                     number("soften", "Soften", b.soften, 0...16, "px"), number("angle", "Angle", b.angle, 0...360, "°"),
                     number("altitude", "Altitude", b.altitude, 0...90, "°"), color("highlight", "Highlight", b.highlight),
                     menu("highlightBlend", "Highlight Mode", modes, b.highlightBlend.rawValue),
                     percent("highlightOpacity", "Highlight Opacity", b.highlightOpacity), color("shadow", "Shadow", b.shadow),
                     menu("shadowBlend", "Shadow Mode", modes, b.shadowBlend.rawValue), percent("shadowOpacity", "Shadow Opacity", b.shadowOpacity)]
        }
        return rows
    }

    public static func patch(_ field: StyleField, shown: Double) -> JSONValue {
        guard case .number(_, _, _, let scale) = field.control, scale != 0 else { return .object([field.key: .number(shown)]) }
        return .object([field.key: .number(shown / scale)])
    }
    /// A colour row's patch: a stroke's and a colour overlay's colour is their solid fill.
    public static func patch(_ field: StyleField, color c: FillColor, kind: StyleKind) -> JSONValue {
        if field.key == "color", kind == .stroke || kind == .colorOverlay { return fillPatch(.solid(c)) ?? .object([:]) }
        return .object([field.key: .object(["r": .number(c.r), "g": .number(c.g), "b": .number(c.b), "a": .number(c.a)])])
    }
    /// A chip's or menu's patch; nil when `option` is already chosen. Solid or Gradient converts the stroke's fill.
    public static func choose(_ option: String, field: StyleField, in effect: StyleEffect) -> JSONValue? {
        switch field.control {
        case .chips(_, let selected), .menu(_, let selected): guard option != selected else { return nil }
        default: return nil
        }
        switch field.key {
        case "direction": return .object(["up": .bool(option == "up")])
        case "fill":
            guard case .stroke(let s) = effect.parameters else { return nil }
            return fillPatch(GradientRules.converted(s.fill, to: option == "gradient" ? .linear : .solid, in: unit))
        default: return .object([field.key: .string(option)])
        }
    }
    /// The gradient editor's gesture as a fill patch, through the gradient rules; nil when it changes nothing.
    public static func gradient(_ intent: GradientIntent, on fill: Fill) -> JSONValue? {
        let next: Fill? = switch intent {
        case .type(let type): GradientRules.converted(fill, to: type, in: unit)
        case .add(let offset): GradientRules.addingStop(fill, at: offset)?.fill
        case .move(let index, let offset, _): GradientRules.movingStop(fill, index: index, to: offset).fill
        case .remove(let index): GradientRules.removingStop(fill, index: index)
        case .color(let index, let color, _): GradientRules.recoloring(fill, index: index, to: color)
        case .angle(let degrees, _): GradientRules.rotated(fill, to: degrees, in: unit)
        }
        guard let next, next != fill else { return nil }
        return fillPatch(next)
    }
    public static func drag(of intent: GradientIntent) -> String? {
        switch intent { case .move(_, _, let d): d; case .color(_, _, let d), .angle(_, let d): d; case .type, .add, .remove: nil }
    }
    public static func hex(_ c: FillColor) -> HexColor { HexColor(byte(c.r), byte(c.g), byte(c.b)) }
    public static func color(_ h: HexColor, alpha: Double) -> FillColor { FillColor(r: Double(h.red) / 255, g: Double(h.green) / 255, b: Double(h.blue) / 255, a: alpha) }
    private static func byte(_ v: Double) -> UInt8 { UInt8((min(max(v.isFinite ? v : 0, 0), 1) * 255).rounded()) }
    private static func fillPatch(_ fill: Fill) -> JSONValue? { (try? JSONValue(encoding: fill)).map { .object(["fill": $0]) } }
    private static func color(_ k: String, _ l: String, _ c: FillColor) -> StyleField { StyleField(key: k, label: l, control: .color(c)) }
    private static func menu(_ k: String, _ l: String, _ o: [String], _ s: String) -> StyleField { StyleField(key: k, label: l, control: .menu(o, selected: s)) }
    private static func chips(_ k: String, _ l: String, _ o: [String], _ s: String) -> StyleField { StyleField(key: k, label: l, control: .chips(o, selected: s)) }
    private static func number(_ k: String, _ l: String, _ v: Double, _ r: ClosedRange<Double>, _ u: String, _ x: Double = 1) -> StyleField {
        StyleField(key: k, label: l, control: .number(shown: v * x, range: r, unit: u, scale: x))
    }
    private static func percent(_ k: String, _ l: String, _ v: Double) -> StyleField { number(k, l, v, 0...100, "%", 100) }
}

/// One drag's token: made on its first sample by `make`, kept until `end`, so a scrub is one undo step.
public struct StyleScrub: Hashable, Sendable {
    public private(set) var token: String?
    public init() {}
    public mutating func open(make: () -> String = { UUID().uuidString }) -> String { let made = token ?? make(); token = made; return made }
    public mutating func intent(_ kind: StyleKind, _ patch: JSONValue, make: () -> String = { UUID().uuidString }) -> StyleIntent {
        .set(kind, patch, drag: open(make: make))
    }
    public mutating func end() { token = nil }
}

/// One kind's rows: its defaults, disabled, while the layer doesn't have it. `help` is LayerStyleText.blocked's reason.
public struct LayerStyleRows: View {
    private let effect: StyleEffect?
    private let kind: StyleKind
    private let onIntent: (StyleIntent) -> Void
    private let help: String?
    @State private var scrub = StyleScrub()

    public init(effect: StyleEffect?, kind: StyleKind, help: String? = nil, onIntent: @escaping (StyleIntent) -> Void) {
        self.effect = effect
        self.kind = kind
        self.onIntent = onIntent
        self.help = help
    }
    public var body: some View {
        let shown = effect ?? StyleRules.defaults(kind)
        let reason = help ?? (effect == nil ? LayerStyleText.off(kind) : nil)
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text(LayerStyleText.title(kind))
                .font(SuiteFont.inspectorTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(StyleEdit.fields(shown), id: \.key) { row($0, effect: shown, reason: reason) }
        }
        .disabled(reason != nil).help(reason ?? "")
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    @ViewBuilder private func row(_ field: StyleField, effect: StyleEffect, reason: String?) -> some View {
        switch field.control {
        case .color(let c):
            InspectorColorWellRow(field.label, color: StyleEdit.hex(c), sampleHelp: reason,
                                  onChange: { send(StyleEdit.patch(field, color: StyleEdit.color($0, alpha: c.a), kind: kind)) },
                                  onEnd: { endScrub() })
                .hexIdentifier(field.id)
        case .menu(let options, let selected):
            InspectorPickerRow(field.label, options: options.map { InspectorOption(id: $0, title: LayerStyleText.words($0)) },
                               selection: selected) { choose($0, field, effect) }
                .suiteControl(id: field.id, enabled: reason == nil, reason: reason)
        case .chips(let options, let selected):
            InspectorRow(field.label) {
                ChoiceChips(options: options.map { InspectorOption(id: $0, title: LayerStyleText.words($0), identifier: "\(field.id).\($0)") },
                            selected: selected) { choose($0, field, effect) }
            }
        case .number(let shown, let range, let unit, _):
            InspectorSliderRow(field.label, value: shown, in: range, step: 1, unit: unit, decimals: 0,
                               onChange: { send(StyleEdit.patch(field, shown: $0)) }, onEnd: { endScrub() })
                .suiteControl(id: field.id, enabled: reason == nil, reason: reason)
        case .gradient(let fill):
            GradientEditor(fill: fill, box: StyleEdit.unit, types: [.linear, .radial], typeID: StyleEdit.gradientTypeID, typeHelp: reason) { gesture in
                if let patch = StyleEdit.gradient(gesture, on: fill) { onIntent(.set(kind, patch, drag: StyleEdit.drag(of: gesture))) }
            }
        }
    }
    /// One sample under the drag's token; @State changes only when the drag opens or ends (SwiftUI rule 1).
    private func send(_ patch: JSONValue) {
        var next = scrub
        let intent = next.intent(kind, patch)
        if next != scrub { scrub = next }
        onIntent(intent)
    }
    private func endScrub() { if scrub.token != nil { scrub.end() } }
    private func choose(_ option: String, _ field: StyleField, _ effect: StyleEffect) {
        if let patch = StyleEdit.choose(option, field: field, in: effect) { onIntent(.set(kind, patch, drag: nil)) }
    }
}
