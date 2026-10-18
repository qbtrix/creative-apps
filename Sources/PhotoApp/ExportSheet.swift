// ExportSheet.swift: File > Export… asks for the format (PNG keeps
// transparency; JPEG lies on white) and, for JPEG, the quality, then Export
// opens the save panel. The choices are the window's presentation state;
// values in, closures out. Its controls carry `photo.export.*` accessibility
// identifiers for the UI journeys and the app audit.
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
        SuiteSheet(
            "Export",
            note: format == .png ? "PNG keeps transparent pixels." : "JPEG has no transparency: transparent pixels export white.",
            cancelIdentifier: "photo.export.cancel",
            confirm: .init("Export", identifier: "photo.export.confirm", help: "Export", perform: onExport),
            onCancel: onCancel
        ) {
            Form {
                Picker("Format", selection: Binding(get: { format }, set: { onFormat($0) })) {
                    ForEach(ImageFormat.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("photo.export.format")
                if format == .jpeg {
                    LabeledContent("Quality") {
                        HStack(spacing: SuiteSpacing.s) {
                            Slider(value: Binding(get: { quality }, set: { onQuality($0) }), in: 0.1...1)
                                .accessibilityLabel("Quality")
                                .accessibilityIdentifier("photo.export.quality")
                            Text("\(Int((quality * 100).rounded()))%").font(SuiteFont.monospacedDigits)
                        }
                    }
                }
            }
        }
    }
}
