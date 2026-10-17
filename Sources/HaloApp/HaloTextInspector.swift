// HaloTextInspector.swift: the TEXT slot of Halo's layer inspector (#430,
// TX-6). Shown only while a text layer is selected (`model.selectedText`):
// the TEXT header; a system TextField (`halo.inspector.text.string`) holding
// a view-local draft of the words, sent as .setText on Return and when focus
// leaves (a blank commit is refused by the Model and the field goes back to
// the stored words); an InspectorSliderRow for the size
// (`halo.inspector.text.size`, `sizeText` as its accessibility value) that
// sends .setFontSize per sample and .endTextSizeScrub at the end, one step;
// an InspectorColorRow (`halo.inspector.text.color`, from
// `selectedLayerColor`) that sends .setLayerColor in 8-bit sRGB; then the refusal's caption when the
// Model's refusal names one of these controls. Each control is disabled with
// `model.unavailableHelp(for:)` (the text area's `textHelp`) as help while it
// can't act. It only reads the model and calls `perform`; it owns the draft
// and the field's focus.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTextInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// The field's words while typing; nil shows the stored words.
    @State private var draft: String?
    @FocusState private var editing: Bool

    static let stringID = "halo.inspector.text.string"
    static let sizeID = "halo.inspector.text.size"
    static let colorID = "halo.inspector.text.color"

    var body: some View {
        if let text = model.selectedText {
            VStack(alignment: .leading, spacing: 0) {
                InspectorSection("Text") {
                    field(text)
                    size(text)
                    if let current = model.selectedLayerColor { color(current) }
                }
                if let refusal = model.refusal, [Self.stringID, Self.sizeID, Self.colorID].contains(refusal.control) {
                    HaloRefusalCaption(refusal: refusal)
                }
            }
        }
    }

    /// The words: a draft while typing, committed on Return or focus loss.
    private func field(_ text: HaloTextContent) -> some View {
        let help = model.unavailableHelp(for: .setText(text.string))
        return TextField("Text", text: Binding(get: { draft ?? text.string }, set: { draft = $0 }))
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .focused($editing)
            .onSubmit(commit)
            .onChange(of: editing) { _, isEditing in if !isEditing { commit() } }
            .disabled(help != nil)
            .help(help ?? "Text")
            .accessibilityLabel("Text")
            .haloControl(id: Self.stringID, enabled: help == nil, help: help)
    }

    /// The size bar, in composition pixels.
    private func size(_ text: HaloTextContent) -> some View {
        let help = model.unavailableHelp(for: .setFontSize(text.fontSize))
        return InspectorSliderRow(
            "Size", value: text.fontSize, in: HaloTextContent.fontSizeRange, step: 1, unit: "px", decimals: 0,
            onChange: { perform(.setFontSize($0)) },
            onEnd: { perform(.endTextSizeScrub) })
            .disabled(help != nil)
            .help(help ?? "Size")
            .accessibilityValue(Text(verbatim: text.sizeText))
            .haloControl(id: Self.sizeID, enabled: help == nil, help: help)
    }

    /// The layer color as an 8-bit sRGB well and hex field.
    private func color(_ current: HaloLayerColor) -> some View {
        let help = model.unavailableHelp(for: .setLayerColor(current))
        let b = current.bytes
        return InspectorColorRow("Color", hex: HexColor(b.red, b.green, b.blue)) { hex in
            perform(.setLayerColor(HaloLayerColor(bytes: hex.red, hex.green, hex.blue)))
        }
        .disabled(help != nil)
        .help(help ?? "Color")
        .haloControl(id: Self.colorID, enabled: help == nil, help: help)
    }

    /// Sends the draft, if any, and shows the stored words again.
    private func commit() {
        guard let words = draft else { return }
        draft = nil
        perform(.setText(words))
    }
}
