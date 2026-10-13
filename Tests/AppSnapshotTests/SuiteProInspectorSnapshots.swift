// SuiteProInspectorSnapshots.swift: the "Pro density" inspector from
// docs/design.md, built only from SuiteUI: an InspectorHeader, collapsible
// InspectorSections of InspectorRows with ScrubFields, a checkbox row, a menu
// picker, a slider row, and a ViewerStatusBar under a viewer. Light and Dark.
// Writes suiteui-pro-inspector-light.png and suiteui-pro-inspector-dark.png.
// The AppKit controls (slider, checkbox, picker, stepper) render for real.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteProInspectorSnapshots {
    @Test func proInspector() throws {
        try snapshot(ProInspectorSample(), name: "suiteui-pro-inspector-light", scheme: .light)
        try snapshot(ProInspectorSample(), name: "suiteui-pro-inspector-dark", scheme: .dark)
    }
}

/// A selected layer's inspector at the column's ideal width, beside a viewer
/// with its status line.
private struct ProInspectorSample: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            VStack(spacing: 0) {
                CanvasSurface(artboard: CGSize(width: 1920, height: 1080))
                ViewerStatusBar(zoom: 0.51, size: "1920 × 1080 px") {
                    Text("sRGB · 8 bits")
                }
            }
            .frame(width: 720, height: 460)
            VStack(alignment: .leading, spacing: 0) {
                InspectorHeader("Background", details: ["1920 × 1080 px", "sRGB · 8 bits per channel"])
                InspectorSection("Layer") {
                    InspectorPickerRow(
                        "Blend Mode",
                        options: [InspectorOption(id: "normal", title: "Normal"), InspectorOption(id: "multiply", title: "Multiply")],
                        selection: "normal"
                    ) { _ in }
                    InspectorRow("Opacity") { ScrubField("Opacity", value: 100, in: 0...100, unit: "%") { _ in } }
                    InspectorRow("") { Toggle("Visible", isOn: .constant(true)).toggleStyle(.checkbox) }
                }
                InspectorSection("Exposure") {
                    InspectorRow("") { Toggle("Enabled", isOn: .constant(true)).toggleStyle(.checkbox) }
                    InspectorRow("Exposure") { ScrubField("Exposure", value: 0.35, in: -5...5, unit: "EV") { _ in } }
                    InspectorSliderRow("Gamma", value: 1, in: 0.1...10) { _ in }
                }
                InspectorSection("Transform") {
                    InspectorRow("Position X") { ScrubField("Position X", value: 960, in: -9999...9999, unit: "px") { _ in } }
                    InspectorRow("Position Y") { ScrubField("Position Y", value: 540, in: -9999...9999, unit: "px") { _ in } }
                    InspectorStepperRow("Rotation", value: -12.5, in: -180...180, step: 0.5, unit: "°") { _ in }
                }
                InspectorSection("Blur", isExpanded: false) {
                    InspectorRow("Radius") { ScrubField("Radius", value: 0, in: 0...100, unit: "px") { _ in } }
                }
            }
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .background(SuiteColor.panel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SuiteSpacing.xxl)
    }
}
