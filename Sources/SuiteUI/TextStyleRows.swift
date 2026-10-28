// TextStyleRows.swift (text-style TS-2): the one text style inspector every
// app shows for a text layer, over SuiteKernel's TextStyle. The font picker
// (FontPicker: family, face for weight and italic, size), an Italic checkbox,
// the four alignment buttons (Justify the fourth) and the Line Height and
// Letter Spacing bar sliders, in TextStyleRules' ranges. The rows never edit
// a document: each control asks `onIntent` for exactly one TextIntent, which
// the host runs as its text command; a scrub's samples share one drag token,
// so the host makes the gesture one undo step. A value that changes nothing
// asks for none. With no style, or `help`, every control is disabled and says
// why; Italic is disabled on a family without the other face. Identifiers
// `suite.text.font` (the picker keeps its own `suite.fontpicker.*` parts),
// `suite.text.italic`, `suite.text.alignment.<alignment>`,
// `suite.text.line-height` and `suite.text.tracking`.
import Foundation
import SuiteKernel
import SuiteModel
import SwiftUI

/// The font picker, Italic, alignment, Line Height and Letter Spacing for one text style; `nil` shows them disabled.
public struct TextStyleRows: View {
    private let style: TextStyle?
    private let families: [FontFamily]
    private let help: String?
    private let onIntent: @MainActor (TextIntent) -> Void
    @State private var drag: String?

    /// `style` is the selected text layer's (nil: none selected); `families` the fonts the picker lists; `help` says
    /// why the style can't change now. `onIntent` gets each edit the rows ask for.
    public init(style: TextStyle?, families: [FontFamily], help: String?,
                onIntent: @escaping @MainActor (TextIntent) -> Void) {
        self.style = style
        self.families = families
        self.help = help
        self.onIntent = onIntent
    }

    public var body: some View {
        let reason = Self.reason(style: style, help: help)
        let item = style ?? .standard
        let pick = Self.pick(item, families: families)
        let italicWhy = reason ?? Self.italicReason(item, families: families)
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            FontPicker(families: families, pick: pick) { next in
                Self.intents(from: pick, to: next).forEach { onIntent($0) }
            }
            .suiteControl(id: "suite.text.font", enabled: reason == nil, reason: reason, identifies: false)
            InspectorRow("") {
                Toggle("Italic", isOn: Binding(get: { item.italic }, set: { on in
                    if let intent = Self.italicIntent(item, on: on) { onIntent(intent) }
                }))
                .toggleStyle(.checkbox)
            }
            .disabled(italicWhy != nil)
            .help(italicWhy ?? "")
            .suiteControl(id: "suite.text.italic", enabled: italicWhy == nil, reason: italicWhy)
            HStack(spacing: SuiteSpacing.xs) {
                ForEach(Self.alignments(item, reason: reason, onIntent: onIntent), id: \.id) {
                    InspectorAction($0, iconOnly: true, isToggle: true)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Alignment")
            .suiteControl(id: "suite.text.alignment", enabled: reason == nil, reason: reason, identifies: false)
            ForEach(Self.scrubs, id: \.id) { scrub in
                InspectorSliderRow(scrub.title, value: Self.value(scrub.field, of: item),
                                   in: TextStyleRules.range(scrub.field), unit: Self.unit(scrub.field),
                                   decimals: Self.decimals(scrub.field),
                                   onChange: { edit(scrub.field, to: $0) }, onEnd: { drag = nil })
                    .suiteControl(id: scrub.id, enabled: reason == nil, reason: reason)
            }
        }
        .disabled(reason != nil)
        .help(reason ?? "")
    }

    /// One scrub edit: the gesture's token (made on its first change), then the one intent it asks for.
    private func edit(_ field: TextStyleField, to value: Double) {
        guard let style else { return }
        let token = CoalesceKey.token(drag)
        drag = token
        if let intent = Self.intent(field, to: value, from: style, drag: token) { onIntent(intent) }
    }

    /// The kernel's words for no text layer (TextCommands), so the rows and the commands say the same.
    nonisolated static let noText = "Select a text layer first."
    nonisolated static let noItalic = "This family has no italic."
    nonisolated static let noUpright = "This family has no upright face."

    /// Every control's identifier, in the order the rows draw them.
    nonisolated static let controlIDs = ["suite.text.font", "suite.text.italic", "suite.text.alignment",
                                         "suite.text.line-height", "suite.text.tracking"]

    /// Why nothing can change: no text layer, or the host's `help`; nil when the rows act.
    nonisolated static func reason(style: TextStyle?, help: String?) -> String? {
        style == nil ? noText : help
    }

    /// The face names a style's weight reads as when its family isn't listed (the system font).
    nonisolated static func faceName(weight: Int, italic: Bool) -> String {
        let names = [100: "Thin", 200: "Extra Light", 300: "Light", 400: "Regular", 500: "Medium",
                     600: "Semibold", 700: "Bold", 800: "Heavy", 900: "Black"]
        let name = names[weight] ?? "\(weight)"
        return italic ? (weight == 400 ? "Italic" : "\(name) Italic") : name
    }

    /// The picker's value for `style`: its family's face with the style's weight and slant, else one named for them.
    nonisolated static func pick(_ style: TextStyle, families: [FontFamily]) -> FontPick {
        let family = families.first { $0.name == style.family }
        let face = family?.faces.first { $0.weight == style.weight && $0.italic == style.italic }
            ?? FontFace(name: faceName(weight: style.weight, italic: style.italic), weight: style.weight,
                        italic: style.italic)
        return FontPick(family: style.family, face: face, size: style.size)
    }

    /// The intents a picker change asks for: `.font` when the family or face changed, `.size` when the size did.
    nonisolated static func intents(from pick: FontPick, to next: FontPick) -> [TextIntent] {
        var intents = [TextIntent]()
        if next.family != pick.family || next.face != pick.face {
            intents.append(.font(family: next.family, weight: next.face.weight, italic: next.face.italic))
        }
        if next.size != pick.size { intents.append(.size(next.size, drag: nil)) }
        return intents
    }

    /// Italic set to `on`: the same family and weight with the slant flipped; nil when unchanged.
    nonisolated static func italicIntent(_ style: TextStyle, on: Bool) -> TextIntent? {
        on == style.italic ? nil : .font(family: style.family, weight: style.weight, italic: on)
    }

    /// Why Italic can't flip: a listed family with no face of the other slant; nil when it can.
    nonisolated static func italicReason(_ style: TextStyle, families: [FontFamily]) -> String? {
        guard let family = families.first(where: { $0.name == style.family }),
              !family.faces.contains(where: { $0.italic != style.italic }) else { return nil }
        return style.italic ? noUpright : noItalic
    }

    /// Align Left, Center, Right and Justify, each asking for its `.alignment`; the current one selected.
    @MainActor static func alignments(_ style: TextStyle, reason: String?,
                                      onIntent: @escaping @MainActor (TextIntent) -> Void) -> [ToolbarAction] {
        let all: [(TextStyle.Alignment, String, String)] = [
            (.leading, "Align Left", "text.alignleft"), (.center, "Align Center", "text.aligncenter"),
            (.trailing, "Align Right", "text.alignright"), (.justified, "Justify", "text.justify"),
        ]
        return all.map { alignment, title, symbol in
            let current = style.paragraph.alignment == alignment
            return ToolbarAction(title, systemImage: symbol, isSelected: current, unavailableHelp: reason,
                                 identifier: "suite.text.alignment.\(alignment.rawValue)", isToggle: true) {
                if !current { onIntent(.alignment(alignment)) }
            }
        }
    }

    /// One bar slider: the field it scrubs, its label and its identifier.
    struct Scrub: Sendable {
        let field: TextStyleField, title: String, id: String
    }

    nonisolated static let scrubs = [Scrub(field: .lineHeight, title: "Line Height", id: "suite.text.line-height"),
                                     Scrub(field: .tracking, title: "Letter Spacing", id: "suite.text.tracking")]

    /// The scrubbed value: line height as a multiple of the line, tracking in thousandths of an em; size in points.
    nonisolated static func value(_ field: TextStyleField, of style: TextStyle) -> Double {
        switch field {
        case .size: style.size
        case .lineHeight: style.paragraph.lineHeight
        case .tracking: style.paragraph.tracking
        }
    }

    /// The places shown: line height to hundredths (1.25), tracking and size whole.
    nonisolated static func decimals(_ field: TextStyleField) -> Int { field == .lineHeight ? 2 : 0 }

    /// The unit shown: × for a line multiple, points for size, none for tracking's thousandths of an em.
    nonisolated static func unit(_ field: TextStyleField) -> String {
        switch field {
        case .size: "pt"
        case .lineHeight: "×"
        case .tracking: ""
        }
    }

    /// The one intent setting `field` to `value` asks for, clamped by TextStyleRules; nil when not a number or unchanged.
    nonisolated static func intent(_ field: TextStyleField, to value: Double, from style: TextStyle,
                                   drag: String?) -> TextIntent? {
        guard value.isFinite else { return nil }
        let kept = Self.value(field, of: TextStyleRules.setting(style, field, to: value))
        guard kept != Self.value(field, of: style) else { return nil }
        switch field {
        case .size: return .size(kept, drag: drag)
        case .lineHeight: return .lineHeight(kept, drag: drag)
        case .tracking: return .tracking(kept, drag: drag)
        }
    }
}
