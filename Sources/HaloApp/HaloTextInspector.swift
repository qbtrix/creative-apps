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
// an InspectorColorWellRow (`halo.inspector.text.color`, from
// `selectedLayerColor`) that sends .setLayerColor in 8-bit sRGB. A refusal
// naming one of these controls shows once, right under that control
// (`textRefusal(at:)`, #2181); `owns` keeps the layer inspector's catch-all
// caption off them (#2175). Each control is disabled with
// `model.unavailableHelp(for:)` (the text area's `textHelp`) as help while it
// can't act. It only reads the model and calls `perform`; it owns the draft
// and the field's focus. A draft left on another layer neither shows nor
// commits, and the next keystroke starts a draft for the selected one. A new
// selection, or an Undo or Redo that changes the words, drops the draft, ends
// editing and rebuilds the field (keyed by `textFieldKey`, #4310), so a stale
// edit buffer never shows over the stored words. Above the colour row,
// SuiteUI's TextStyleRows (text-style TS-4) over the layer's size on the
// kernel's standard style, the font picker listing this Mac's families;
// disabled with `textStylesHelp` until TS-9 gives Halo's text layer a style
// and routes the rows' intents to its text commands.
import HaloModel
import SuiteKernel
import SuiteShell
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

    /// Why the shared text style rows can't act yet: Halo's text commands take them in TS-10.
    nonisolated static let textStylesHelp = "Text styles aren't connected in this window yet."

    /// The font families the shared rows' picker lists: this Mac's, read once.
    nonisolated static let fontFamilies = FontCatalog().families()

    /// The layer's style as the kernel's: the standard style at the layer's size, which is all Halo stores yet.
    nonisolated static func kernelStyle(_ text: HaloTextContent) -> TextStyle {
        var style = TextStyle.standard
        style.size = text.fontSize
        return style
    }

    /// Whether `refusal` names a TEXT control, so it shows here and only here.
    static func owns(_ refusal: HaloRefusal) -> Bool { HaloProject.textOwns(refusal) }

    var body: some View {
        if let text = model.selectedText {
            InspectorSection("Text") {
                field(text)
                caption(Self.stringID)
                size(text)
                caption(Self.sizeID)
                TextStyleRows(style: Self.kernelStyle(text), families: Self.fontFamilies, help: Self.textStylesHelp) { _ in }
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
                .id(model.textFieldKey)
                .onChange(of: model.textFieldKey) { reset() }
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
        return InspectorColorWellRow("Color", color: current.hex) {
            perform(.setLayerColor(HaloLayerColor(hex: $0)))
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

    /// On a new selection or new stored words: drops the draft unsent, then ends editing.
    private func reset() {
        draft = nil
        editing = false
    }
}

/// Halo's one bridge to SuiteUI's HexColor, over the layer color's 8-bit
/// sRGB `bytes` (each channel clamped, times 255, rounded).
extension HaloLayerColor {
    init(hex: HexColor) { self.init(bytes: hex.red, hex.green, hex.blue) }

    var hex: HexColor {
        let b = bytes
        return HexColor(b.red, b.green, b.blue)
    }
}
