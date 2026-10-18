// HaloTextInspector.swift: the TEXT slot of Halo's layer inspector (#430,
// TX-6). Shown only while a text layer is selected (`model.selectedText`):
// the TEXT header; a plain TextField in a filled InspectorRow, lit while
// typing like InspectorColorRow's hex field (`halo.inspector.text.string`),
// holding a view-local draft of the words kept with the layer it was typed for
// (HaloTextDraft), sent as .setText on Return and when focus leaves only
// while that layer is still selected (#2177; a blank commit is refused by
// the Model and the field goes back to the stored words); an
// InspectorSliderRow for the size (`halo.inspector.text.size`, `sizeText` as
// its accessibility value) that drags over `sizeBarRange`, so the usual
// sizes sit clear of its label, and types over `fontSizeRange` (#2180), and
// sends .setFontSize per sample and .endTextSizeScrub at the end, one step;
// an InspectorColorRow (`halo.inspector.text.color`, from
// `selectedLayerColor`) that sends .setLayerColor in 8-bit sRGB. A refusal
// naming one of these controls shows once, right under that control
// (`textRefusal(at:)`, #2181); `owns` keeps the layer inspector's catch-all
// caption off them (#2175). Each control is disabled with
// `model.unavailableHelp(for:)` (the text area's `textHelp`) as help while it
// can't act. It only reads the model and calls `perform`; it owns the draft
// and the field's focus. A draft left on another layer neither shows nor
// commits, and the next keystroke starts a draft for the selected one. A new
// selection drops the draft, ends editing and rebuilds the field (keyed by
// `selectedLayerID`), so the old edit buffer never shows on the next layer.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloTextInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// The field's words while typing and their layer; nil shows the stored words.
    @State private var draft: HaloTextDraft?
    @FocusState private var editing: Bool

    static let stringID = "halo.inspector.text.string"
    static let sizeID = "halo.inspector.text.size"
    static let colorID = "halo.inspector.text.color"

    /// Whether `refusal` names a TEXT control, so it shows here and only here.
    static func owns(_ refusal: HaloRefusal) -> Bool { HaloProject.textOwns(refusal) }

    var body: some View {
        if let text = model.selectedText {
            InspectorSection("Text") {
                field(text)
                caption(Self.stringID)
                size(text)
                caption(Self.sizeID)
                if let current = model.selectedLayerColor {
                    color(current)
                    caption(Self.colorID)
                }
            }
        }
    }

    /// The refusal's caption when it names `control`.
    @ViewBuilder private func caption(_ control: String) -> some View {
        if let refusal = model.textRefusal(at: control) {
            InspectorNote(refusal.message, kind: .error, identifier: "halo.refusal")
        }
    }

    /// The words: a draft while typing, committed on Return or focus loss.
    private func field(_ text: HaloTextContent) -> some View {
        let help = model.unavailableHelp(for: .setText(text.string))
        let layerID = model.selectedLayerID
        let words = Binding(
            get: { model.textFieldWords(draft: draft) ?? text.string },
            set: { typed in draft = layerID.map { HaloTextDraft(layerID: $0, words: typed) } })
        return InspectorRow("") {
            TextField("Text", text: words)
                .textFieldStyle(.plain)
                .labelsHidden()
                .font(SuiteFont.inspectorValue)
                .focused($editing)
                .onSubmit(commit)
                .onChange(of: editing) { _, isEditing in if !isEditing { commit() } }
                .background {
                    if editing { RoundedRectangle(cornerRadius: SuiteRadius.field).fill(SuiteColor.fieldActive).padding(-SuiteSpacing.xs) }
                }
                .disabled(help != nil)
                .help(help ?? "Text")
                .accessibilityLabel("Text")
                .haloControl(id: Self.stringID, enabled: help == nil, help: help)
                .id(layerID)
                .onChange(of: model.selectedLayerID) { reset() }
        }
    }

    /// The size bar, in composition pixels: drags over `sizeBarRange`, types
    /// over `fontSizeRange`.
    private func size(_ text: HaloTextContent) -> some View {
        let help = model.unavailableHelp(for: .setFontSize(text.fontSize))
        let track = ScrubTrack(
            positions: HaloTextContent.sizeBarRange, step: 1, position: { HaloTextContent.sizeBarPosition($0) },
            value: { $0 })
        return InspectorSliderRow(
            "Size", value: text.fontSize, in: HaloTextContent.fontSizeRange, step: 1, unit: "px", decimals: 0,
            track: track,
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

    /// Sends the draft while its layer is still selected, and shows the
    /// stored words again; a draft for another layer is dropped.
    private func commit() {
        guard let pending = draft else { return }
        draft = nil
        if let command = pending.commit(on: model) { perform(command) }
    }

    /// On a new selection: drops the old layer's draft unsent, then ends editing.
    private func reset() {
        draft = nil
        editing = false
    }
}
