// ExportSheet.swift: File > Export… asks for the format (PNG keeps
// transparency; JPEG lies on white) and, for JPEG, the quality, then Export
// opens the save panel. The choices are the window's presentation state;
// values in, closures out. Export is the catalog's `file.export` item
// (command-state CS-10): the workspace's availability turns it on and gives
// its help. Its controls carry `photo.export.*` accessibility identifiers for
// the UI journeys and the app audit.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct ExportSheet: View {
    let format: ImageFormat
    let quality: Double
    /// What `file.export`'s availability reads.
    var workspace = PhotoWorkspace()
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
            Text(format == .png ? "PNG keeps transparent pixels." : "JPEG has no transparency: transparent pixels export white.")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("photo.export.cancel")
                if let spec = PhotoWorkspace.catalog.spec("file.export") {
                    MenuCommand(spec, on: workspace, title: "Export", shortcut: .defaultAction, perform: onExport)
                        .accessibilityIdentifier("photo.export.confirm")
                }
            }
        }
        .padding(SuiteSpacing.l)
        .frame(width: SuiteSize.inspectorWidth.max)
    }
}
