// ImageSizeSheet.swift: Image > Image Size… asks for the new width and height
// in pixels, keeping the proportions while the box is checked
// (CanvasSize.height(forWidth:) and width(forHeight:)), then Resize resamples
// every layer. The typed numbers are presentation state until Resize.
import PhotoModel
import SuiteUI
import SwiftUI

struct ImageSizeSheet: View {
    let size: CanvasSize
    var onResize: @MainActor (Int, Int) -> Void = { _, _ in }
    var onCancel: @MainActor () -> Void = {}
    @State private var width: Int
    @State private var height: Int
    @State private var keepsProportions = true

    init(size: CanvasSize, onResize: @escaping @MainActor (Int, Int) -> Void, onCancel: @escaping @MainActor () -> Void) {
        self.size = size
        self.onResize = onResize
        self.onCancel = onCancel
        _width = State(initialValue: size.width)
        _height = State(initialValue: size.height)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Image Size").font(SuiteFont.headline)
            Form {
                TextField("Width", value: Binding(get: { width }, set: { setWidth($0) }), format: .number)
                TextField("Height", value: Binding(get: { height }, set: { setHeight($0) }), format: .number)
                Toggle("Keep proportions", isOn: $keepsProportions).toggleStyle(.checkbox)
            }
            Text("Now \(size.width) × \(size.height) px. Each side can be 1 to \(PhotoWorkspace.maxSide) px.")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Resize") { onResize(width, height) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(SuiteSpacing.l)
        .frame(width: SuiteSize.inspectorWidth.max)
    }

    private func setWidth(_ value: Int) {
        width = value
        if keepsProportions { height = size.height(forWidth: value) }
    }

    private func setHeight(_ value: Int) {
        height = value
        if keepsProportions { width = size.width(forHeight: value) }
    }
}
