// ImageSizeSheet.swift: Image > Image Size… asks for the new width and height
// in pixels, keeping the proportions while the box is checked
// (CanvasSize.height(forWidth:) and width(forHeight:)), then Resize resamples
// every layer. The typed sides are presentation state until Resize, kept as
// text: a text field's binding follows every keystroke, while a number field
// on macOS may wait for Return or Tab to commit, and Return is Resize's own
// shortcut, so "type 400, press Return" must never resize with the old
// number. Resize stays disabled, saying why, until both sides are whole
// numbers. Its controls carry `photo.size.*` accessibility identifiers.
import PhotoModel
import SuiteUI
import SwiftUI

struct ImageSizeSheet: View {
    let size: CanvasSize
    var onResize: @MainActor (Int, Int) -> Void = { _, _ in }
    var onCancel: @MainActor () -> Void = {}
    @State private var width: String
    @State private var height: String
    @State private var keepsProportions = true

    init(size: CanvasSize, onResize: @escaping @MainActor (Int, Int) -> Void, onCancel: @escaping @MainActor () -> Void) {
        self.size = size
        self.onResize = onResize
        self.onCancel = onCancel
        _width = State(initialValue: String(size.width))
        _height = State(initialValue: String(size.height))
    }

    var body: some View {
        let sides = Self.side(width).flatMap { w in Self.side(height).map { (w, $0) } }
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Image Size").font(SuiteFont.headline)
            Form {
                TextField("Width", text: Binding(get: { width }, set: { setWidth($0) }))
                    .accessibilityIdentifier("photo.size.width")
                TextField("Height", text: Binding(get: { height }, set: { setHeight($0) }))
                    .accessibilityIdentifier("photo.size.height")
                Toggle("Keep proportions", isOn: $keepsProportions).toggleStyle(.checkbox)
                    .accessibilityIdentifier("photo.size.keep-proportions")
            }
            Text("Now \(size.width) × \(size.height) px. Each side can be 1 to \(PhotoWorkspace.maxSide) px.")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("photo.size.cancel")
                Button("Resize") { if let sides { onResize(sides.0, sides.1) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(sides == nil)
                    .help(sides == nil ? "Type each side as a whole number of pixels." : "Resize")
                    .accessibilityIdentifier("photo.size.resize")
            }
        }
        .padding(SuiteSpacing.l)
        .frame(width: SuiteSize.inspectorWidth.max)
    }

    /// A typed side as a whole number, or nil.
    private static func side(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    private func setWidth(_ text: String) {
        width = text
        if keepsProportions, let value = Self.side(text) { height = String(size.height(forWidth: value)) }
    }

    private func setHeight(_ text: String) {
        height = text
        if keepsProportions, let value = Self.side(text) { width = String(size.width(forHeight: value)) }
    }
}
