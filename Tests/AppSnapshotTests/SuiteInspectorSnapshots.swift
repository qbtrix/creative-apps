// SuiteInspectorSnapshots.swift: SuiteUI's inspector rows, one section per row
// kind, at the inspector's ideal width, in Light and Dark. Writes
// suiteui-inspector-light.png and suiteui-inspector-dark.png, with the system
// controls drawn for real (the snapshot helper renders through AppKit).
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteInspectorSnapshots {
    @Test func inspector() throws {
        try snapshot(InspectorSample(), name: "suiteui-inspector-light", scheme: .light)
        try snapshot(InspectorSample(), name: "suiteui-inspector-dark", scheme: .dark)
    }
}

/// Sample data over every row kind, laid out like the inspector column.
private struct InspectorSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            InspectorSection("Layer") {
                InspectorSliderRow("Opacity", value: 80, in: 0...100, unit: "%") { _ in }
                InspectorSliderRow("Rotation", value: -12.5, in: -180...180, unit: "°") { _ in }
            }
            InspectorSection("Size") {
                InspectorStepperRow("Width", value: 640, in: 1...4096, unit: "pt") { _ in }
                InspectorStepperRow("Stroke", value: 1.5, in: 0...20, step: 0.5, unit: "pt") { _ in }
            }
            InspectorSection("Color") {
                InspectorColorRow("Fill", color: .orange) { _ in }
                InspectorColorRow("Stroke", color: .indigo, supportsOpacity: false) { _ in }
            }
            InspectorSection("Blending") {
                InspectorPickerRow(
                    "Mode",
                    options: [
                        InspectorOption(id: "normal", title: "Normal"),
                        InspectorOption(id: "multiply", title: "Multiply"),
                        InspectorOption(id: "screen", title: "Screen"),
                    ],
                    selection: "multiply"
                ) { _ in }
            }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SuiteSpacing.xxl)
    }
}
