// PhotoTextInspector.swift (text-layers TX-4): the Text section of a Photo window's inspector, shown while
// a text layer is selected. Family is a picker over the text services' families (the layer's family as the
// service resolves it, so "System" shows as the system family), Weight and Style chips over that family's
// faces, a Color row (colour and opacity), Size, Line height and Tracking scrub fields, Alignment chips. Every chip
// carries its own identifier (`photo.text.alignment.trailing`, `photo.text.weight.700`). Each change is
// one `.text(.style(...))` intent, one step; a scrub field commits once per gesture (onEnd), never per
// drag sample, so the text is laid out once per gesture (docs/render-contract.md). Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The values the scrub fields will commit when their gesture ends. Not observed, so a drag sample
/// writes nothing SwiftUI watches.
@MainActor final class PhotoTextScrub {
    var size: Double?
    var lineHeight: Double?
    var tracking: Double?
    /// The colour row's open gesture's drag token; nil between gestures.
    var colorDrag: String?
}

/// The selected text layer's Text section; nothing while no text layer is selected.
struct PhotoTextInspector: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    @State private var scrub = PhotoTextScrub()

    static let weightNames: [Int: String] = [
        100: "Thin", 200: "Extra Light", 300: "Light", 400: "Regular", 500: "Medium",
        600: "Semibold", 700: "Bold", 800: "Heavy", 900: "Black",
    ]

    static let alignments: [InspectorOption<TextStyle.Alignment>] = [
        InspectorOption(id: .leading, title: "Left", identifier: "photo.text.alignment.leading"),
        InspectorOption(id: .center, title: "Center", identifier: "photo.text.alignment.center"),
        InspectorOption(id: .trailing, title: "Right", identifier: "photo.text.alignment.trailing"),
        InspectorOption(id: .justified, title: "Justified", identifier: "photo.text.alignment.justified"),
    ]

    static let slants = [
        InspectorOption(id: false, title: "Upright", identifier: "photo.text.italic.upright"),
        InspectorOption(id: true, title: "Italic", identifier: "photo.text.italic.italic"),
    ]

    var body: some View {
        if let style = model.textStyle {
            let help = model.textHelp
            let family = model.textFamily(style.family)
            let faces = model.faces(of: family)
            InspectorSection("Text") {
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    InspectorPickerRow(
                        "Family", options: families(family).map { InspectorOption(id: $0, title: $0) },
                        selection: family
                    ) { send(.font(family: $0, weight: nil, italic: nil)) }
                        .control("photo.text.family", help: help)
                    chips("Weight", Self.weights(faces), selected: style.weight, id: "photo.text.weight", help: help) {
                        send(.font(family: family, weight: $0, italic: nil))
                    }
                    if faces.contains(where: { $0.italic }) {
                        chips("Style", Self.slants, selected: style.italic, id: "photo.text.italic", help: help) {
                            send(.font(family: family, weight: nil, italic: $0))
                        }
                    }
                    colorRow(style.rgba, help: help)
                    scrubRow("Size", value: style.size, in: TextStyleRules.range(.size), unit: "pt", id: "photo.text.size",
                             help: help, keep: { scrub.size = $0 }) { scrub.size.map { .size($0, drag: nil) } }
                    chips("Alignment", Self.alignments, selected: style.paragraph.alignment, id: "photo.text.alignment",
                          help: help) { send(.alignment($0)) }
                    scrubRow("Line height", value: style.paragraph.lineHeight, in: TextStyleRules.range(.lineHeight),
                             unit: "×", id: "photo.text.line-height", help: help, keep: { scrub.lineHeight = $0 }) {
                        scrub.lineHeight.map { .lineHeight($0, drag: nil) }
                    }
                    scrubRow("Tracking", value: style.paragraph.tracking, in: TextStyleRules.range(.tracking),
                             unit: "", id: "photo.text.tracking", help: help, keep: { scrub.tracking = $0 }) {
                        scrub.tracking.map { .tracking($0, drag: nil) }
                    }
                    if let help { InspectorNote(help) }
                }
            }
        }
    }

    private func send(_ intent: TextIntent) { perform(.text(.style(intent))) }

    /// The words' colour and opacity: a run of panel picks, or one hex commit, is one step.
    private func colorRow(_ rgba: [UInt8], help: String?) -> some View {
        let channel = { (i: Int) in rgba.indices.contains(i) ? rgba[i] : 255 }
        return InspectorColorWellRow(
            "Color", color: HexColor(channel(0), channel(1), channel(2)), opacity: Double(channel(3)) / 255
        ) { hex, opacity in
            let drag = CoalesceKey.token(scrub.colorDrag)
            scrub.colorDrag = drag
            let alpha = opacity.isFinite ? UInt8((min(max(opacity, 0), 1) * 255).rounded()) : 255
            perform(.text(.color([hex.red, hex.green, hex.blue, alpha], drag: drag)))
        } onEnd: {
            scrub.colorDrag = nil
        }
        .control("photo.text.color", help: help)
    }

    /// The text services' families, with `current` first when they don't list it.
    private func families(_ current: String) -> [String] {
        let names = model.textFamilyNames
        return names.contains(current) ? names : [current] + names
    }

    /// One chip per weight the family has, named.
    static func weights(_ faces: [(weight: Int, italic: Bool)]) -> [InspectorOption<Int>] {
        Set(faces.map { $0.weight }).sorted().map {
            InspectorOption(id: $0, title: Self.weightNames[$0] ?? "\($0)", identifier: "photo.text.weight.\($0)")
        }
    }

    /// A label over a chip group; the group is one control carrying `id`, each chip its own `<id>.<value>` identifier.
    private func chips<ID: Hashable & Sendable>(
        _ label: String, _ options: [InspectorOption<ID>], selected: ID, id: String, help: String?,
        onSelect: @escaping @MainActor (ID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text(label).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            ChoiceChips(options: options, selected: selected, onSelect: onSelect)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(label)
                .control(id, help: help)
        }
    }

    /// A scrub field that keeps each sample with `keep` and sends `commit`'s intent once its gesture ends.
    private func scrubRow(
        _ label: String, value: Double, in range: ClosedRange<Double>, unit: String, id: String, help: String?,
        keep: @escaping @MainActor (Double) -> Void, commit: @escaping @MainActor () -> TextIntent?
    ) -> some View {
        InspectorRow(label) {
            ScrubField(label, value: value, in: range, unit: unit, decimals: range.upperBound > 10 ? 0 : 2) { number in
                if number.isFinite { keep(number) }
            } onEnd: {
                if let intent = commit() { send(intent) }
                scrub.size = nil
                scrub.lineHeight = nil
                scrub.tracking = nil
            }
            // On the field, not the row: its adjustable action is the one VoiceOver and the harness step.
            .control(id, help: help)
        }
    }
}

private extension View {
    /// Disabled with `help` as its tooltip and reason while it can't act; identified by `id`.
    func control(_ id: String, help: String?) -> some View {
        disabled(help != nil).help(help ?? "").suiteControl(id: id, enabled: help == nil, reason: help)
    }
}
