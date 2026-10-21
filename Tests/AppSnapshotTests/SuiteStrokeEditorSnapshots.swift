// SuiteStrokeEditorSnapshots.swift (stroke-style SS-4): StrokeEditor (SS-3) in an inspector-width Stroke section, as
// the gallery's `stroke-editor` page and each app's paint section host it, in Light and Dark. Writes
// suiteui-stroke-editor-{light,dark}.png (a 2 pt black stroke: the colour row, Width, Join, Cap, Dash and Trim
// Start, End and Offset, every row enabled), suiteui-stroke-editor-waiting-core-{light,dark}.png (the dash and trim
// rows disabled with StrokeRules.waitingCore under them, as the page shows them before SS-7),
// suiteui-stroke-editor-no-trim-{light,dark}.png (`showsTrim: false`, Design's editor: no trim rows) and
// suiteui-stroke-editor-no-stroke-{light,dark}.png (Add Stroke alone). The packet's -dashed, -custom-dash and
// -trimmed screens need the stroke's dash and trim fields, which the pinned core doesn't have yet (SS-7); SS-9 adds
// them. macOS only.
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteStrokeEditorSnapshots {
    @Test func strokeEditorStates() throws {
        let stroke = VectorStroke(width: 2)
        let states: [(suffix: String, sample: StrokeEditorSample)] = [
            ("", StrokeEditorSample(stroke: stroke, dashHelp: nil)),
            ("-waiting-core", StrokeEditorSample(stroke: stroke, dashHelp: StrokeRules.waitingCore)),
            ("-no-trim", StrokeEditorSample(stroke: stroke, dashHelp: nil, showsTrim: false)),
            ("-no-stroke", StrokeEditorSample(stroke: nil, dashHelp: nil)),
        ]
        #expect(StrokeEditorRules(stroke: stroke, help: nil, dashHelp: nil, showsTrim: false).rows
            .allSatisfy { ![StrokeEditorRow.trimStart, .trimEnd, .trimOffset].contains($0) },
                "the no-trim state still shows trim rows")
        for (suffix, sample) in states {
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(sample, name: "suiteui-stroke-editor\(suffix)-\(scheme.name)", scheme: scheme)
            }
        }
    }
}

/// The editor in a Stroke section on the panel colour, at the ideal inspector width.
private struct StrokeEditorSample: View {
    let stroke: VectorStroke?
    let dashHelp: String?
    var showsTrim = true

    var body: some View {
        InspectorSection("Stroke") {
            StrokeEditor(stroke: stroke, help: nil, dashHelp: dashHelp, showsTrim: showsTrim) { _ in }
        }
        .padding(.vertical, SuiteSpacing.m)
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
