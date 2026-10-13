// SuiteHeaderSnapshots.swift: InspectorHeader's title and info card, with
// facts (labels left, values right in tabular figures), with the older detail
// lines, with a long name truncated in the middle and with no facts, above a
// section, on the editor panel, in Light and Dark. Writes
// suiteui-header-light.png and suiteui-header-dark.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteHeaderSnapshots {
    @Test func header() throws {
        try snapshot(HeaderSheet(), name: "suiteui-header-light", scheme: .light)
        try snapshot(HeaderSheet(), name: "suiteui-header-dark", scheme: .dark)
    }
}

private struct HeaderSheet: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            panel {
                InspectorHeader(
                    "Hero Banner.png",
                    facts: [
                        InspectorFact("Size", "1920 × 1080 px"), InspectorFact("Color", "sRGB · 8 bits"),
                        InspectorFact("Layers", "3"), InspectorFact("Empty", ""),
                    ])
                InspectorSection("Layer") {
                    InspectorSliderRow("Opacity", value: 100, in: 0...100, unit: "%", decimals: 0) { _ in }
                }
            }
            panel { InspectorHeader("Rectangle", details: ["160 × 120 pt", "Fill #1877F2"]) }
            panel {
                InspectorHeader("A very long layer name that cannot fit in the panel at all.png", details: ["1 of 12"])
                InspectorHeader("Nothing to say")
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func panel(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.bottom, SuiteSpacing.m)
            .frame(width: SuiteSize.editorPanelWidth, alignment: .topLeading)
            .background(SuiteColor.panel)
    }
}
