// CanvasSizeSheet.swift: Image > Canvas Size… (transform PT-3) asks for a
// width and height in pixels, absolute or Relative (added to the image's
// size, the default), and where the image sits in the new canvas: a 3 x 3
// grid of SuiteKernel's BoxAnchor. A smaller side brings "The canvas will be
// cropped." The choices are a CanvasSizeDraft (PhotoModel), the window's
// presentation state, shown by PhotoTransformArea. OK hands the draft to the
// window; it is off, with the reason as its help, while the size is the
// image's own. Values in, closures out; the fields are text fields whose every
// keystroke updates the draft, as in StraightenSheet, and Return in a field is
// OK. Controls carry `photo.canvas-size.*` identifiers.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct CanvasSizeSheet: View {
    let draft: CanvasSizeDraft
    var onDraft: @MainActor (CanvasSizeDraft) -> Void = { _ in }
    var onResize: @MainActor (CanvasSizeDraft) -> Void = { _ in }
    var onCancel: @MainActor () -> Void = {}
    /// The width as typed; nil shows the draft's.
    @State private var typedWidth: String?
    /// The height as typed; nil shows the draft's.
    @State private var typedHeight: String?

    /// The anchor grid's nine cells, top left to bottom right.
    static let anchorOptions = BoxAnchor.allCases.map {
        InspectorOption(id: $0, title: CanvasSizeDraft.anchorTitle($0), identifier: "photo.canvas-size.anchor.\($0.rawValue)")
    }

    /// The crop note, nil while the canvas only grows.
    var cropNote: String? { draft.cropNote }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Canvas Size").font(SuiteFont.headline)
            Form {
                field("Width", text: typedWidth ?? String(draft.width), id: "photo.canvas-size.width", type: typeWidth)
                field("Height", text: typedHeight ?? String(draft.height), id: "photo.canvas-size.height", type: typeHeight)
                Toggle("Relative", isOn: Binding(get: { draft.relative }, set: { setRelative($0) }))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("photo.canvas-size.relative")
            }
            Text("Anchor").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            PresetGrid(options: Self.anchorOptions, selected: draft.anchor, columns: 3, onSelect: chooseAnchor)
            Text("Now \(draft.old.width) × \(draft.old.height) px. New size \(draft.newSize.width) × \(draft.newSize.height) px.")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
            if let note = cropNote {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.stateWarning)
                    .accessibilityIdentifier("photo.canvas-size.crop-note")
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("photo.canvas-size.cancel")
                Button("OK", action: resize).keyboardShortcut(.defaultAction)
                    .disabled(draft.help != nil)
                    .help(draft.help ?? "Resize the canvas to \(draft.newSize.width) × \(draft.newSize.height) px.")
                    .accessibilityIdentifier("photo.canvas-size.ok")
            }
        }
        .padding(SuiteSpacing.l)
        .frame(width: SuiteSize.inspectorWidth.max)
    }

    /// One pixel field: a label, the number and "px".
    private func field(_ title: String, text: String, id: String, type: @escaping @MainActor (String) -> Void) -> some View {
        LabeledContent(title) {
            HStack(spacing: SuiteSpacing.s) {
                TextField(title, text: Binding(get: { text }, set: { type($0) }))
                    .labelsHidden()
                    .frame(width: SuiteSize.inspectorField)
                    // The field takes Return before the default button does.
                    .onSubmit { resize() }
                    .accessibilityLabel(title)
                    .accessibilityIdentifier(id)
                Text("px")
            }
        }
    }

    /// Text that isn't a number yet ("-") keeps the last width.
    func typeWidth(_ text: String) {
        typedWidth = text
        onDraft(draft.with(width: Int(text.trimmingCharacters(in: .whitespaces)) ?? draft.width))
    }

    /// Text that isn't a number yet ("-") keeps the last height.
    func typeHeight(_ text: String) {
        typedHeight = text
        onDraft(draft.with(height: Int(text.trimmingCharacters(in: .whitespaces)) ?? draft.height))
    }

    /// The Relative checkbox: the fields switch, the new size stays.
    func setRelative(_ on: Bool) {
        typedWidth = nil
        typedHeight = nil
        onDraft(draft.with(relative: on))
    }

    func chooseAnchor(_ anchor: BoxAnchor) {
        onDraft(draft.with(anchor: anchor))
    }

    /// OK, or Return in a field: sends the draft unless the size is unchanged.
    func resize() {
        guard draft.help == nil else { return }
        onResize(draft)
    }
}
