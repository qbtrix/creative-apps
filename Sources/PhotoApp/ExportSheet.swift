// ExportSheet.swift: File > Export… asks for the format (PNG keeps
// transparency; JPEG lies on white) and, for JPEG, the quality, then Export
// opens the save panel. The choices are the window's presentation state;
// values in, closures out.
import PhotoModel
import SuiteUI
import SwiftUI

struct ExportSheet: View {
    let format: ImageFormat
    let quality: Double
    var onFormat: @MainActor (ImageFormat) -> Void = { _ in }
    var onQuality: @MainActor (Double) -> Void = { _ in }
    var onExport: @MainActor () -> Void = {}
    var onCancel: @MainActor () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Export").font(SuiteFont.headline)
            Form {
                Picker("Format", selection: Binding(get: { format }, set: { onFormat($0) })) {
                    ForEach(ImageFormat.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if format == .jpeg {
                    LabeledContent("Quality") {
                        HStack(spacing: SuiteSpacing.s) {
                            Slider(value: Binding(get: { quality }, set: { onQuality($0) }), in: 0.1...1)
                                .accessibilityLabel("Quality")
                            Text("\(Int((quality * 100).rounded()))%").font(SuiteFont.monospacedDigits)
                        }
                    }
                }
            }
            Text(format == .png ? "PNG keeps transparent pixels." : "JPEG has no transparency: transparent pixels export white.")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Export", action: onExport).keyboardShortcut(.defaultAction)
            }
        }
        .padding(SuiteSpacing.l)
        .frame(width: SuiteSize.inspectorWidth.max)
    }
}
