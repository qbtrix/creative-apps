// ImageSizeSheet.swift: Image > Image Size… asks for the new width and height
// in pixels, keeping the proportions while the box is checked
// (CanvasSize.height(forWidth:) and width(forHeight:)); checking the box again
// re-derives the height from the width. Resize resamples every layer. The
// typed sides are presentation state until Resize, kept as text: a text
// field's binding follows every keystroke, while a number field on macOS may
// wait for Return or Tab to commit, and Return is Resize's own shortcut.
// Resize reads the sides when it runs, not as the view last drew them, so
// "type 400, press Return" never resizes with an older number; it stays
// disabled, saying why, until both are whole numbers. Its controls carry
// `photo.size.*` accessibility identifiers, and the Form's fields are named
// for VoiceOver (a Form row's title doesn't name its field).
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
        let typed = Self.side(width) != nil && Self.side(height) != nil
        SuiteSheet(
            "Image Size", note: "Now \(size.width) × \(size.height) px. Each side can be 1 to \(PhotoWorkspace.maxSide) px.",
            cancelIdentifier: "photo.size.cancel",
            confirm: .init(
                "Resize", identifier: "photo.size.resize",
                help: typed ? "Resize" : "Type each side as a whole number of pixels.", isEnabled: typed, perform: resize),
            onCancel: onCancel
        ) {
            Form {
                TextField("Width", text: Binding(get: { width }, set: { setWidth($0) }))
                    .accessibilityLabel("Width")
                    .accessibilityIdentifier("photo.size.width")
                TextField("Height", text: Binding(get: { height }, set: { setHeight($0) }))
                    .accessibilityLabel("Height")
                    .accessibilityIdentifier("photo.size.height")
                Toggle("Keep proportions", isOn: Binding(get: { keepsProportions }, set: { setKeepsProportions($0) }))
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("photo.size.keep-proportions")
            }
        }
    }

    /// A typed side as a whole number, or nil.
    private static func side(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    private func resize() {
        guard let w = Self.side(width), let h = Self.side(height) else { return }
        onResize(w, h)
    }

    private func setWidth(_ text: String) {
        width = text
        if keepsProportions, let value = Self.side(text) { height = String(size.height(forWidth: value)) }
    }

    private func setHeight(_ text: String) {
        height = text
        if keepsProportions, let value = Self.side(text) { width = String(size.width(forHeight: value)) }
    }

    private func setKeepsProportions(_ keeps: Bool) {
        keepsProportions = keeps
        if keeps, let value = Self.side(width) { height = String(size.height(forWidth: value)) }
    }
}
