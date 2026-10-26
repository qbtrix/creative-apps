// SuiteGradientEditorSnapshots.swift (gradient-fill GF-4): GradientEditor (GF-3) in an inspector-width Fill section,
// as the gallery's `gradient-editor` page and each app's paint section host it, in Light and Dark. Writes
// suiteui-gradient-editor-{light,dark}.png (a two-stop linear fill, blue to white, 0°: the switch, the stop bar, the
// colour row and the angle row), -radial (no angle row), -three-stops (the middle stop selected), -solid (the bar
// hidden, the colour row alone) and -two-stops-help (the remove refused, its help under the rows). macOS only.
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteGradientEditorSnapshots {
    static let box = Rect(minX: 0, minY: 0, maxX: 200, maxY: 100)
    static let blue = FillColor(r: 0, g: 0, b: 1), red = FillColor(r: 1, g: 0, b: 0)
    static let stops = [GradientStop(offset: 0, color: blue), GradientStop(offset: 1, color: .white)]
    static let linear = Fill.linear(stops: stops, start: Point(x: 0, y: 50), end: Point(x: 200, y: 50))

    @Test func gradientEditorStates() throws {
        let three = Fill.linear(stops: [Self.stops[0], GradientStop(offset: 0.5, color: Self.red), Self.stops[1]],
                                start: Point(x: 0, y: 50), end: Point(x: 200, y: 50))
        let states: [(suffix: String, sample: GradientEditorSample)] = [
            ("", GradientEditorSample(fill: Self.linear)),
            ("-radial", GradientEditorSample(fill: GradientRules.converted(Self.linear, to: .radial, in: Self.box))),
            ("-three-stops", GradientEditorSample(fill: three, selected: 1)),
            ("-solid", GradientEditorSample(fill: .solid(Self.blue))),
            ("-two-stops-help", GradientEditorSample(fill: Self.linear, refused: true)),
        ]
        #expect(!GradientEditor.showsAngleRow(states[1].sample.fill, showsAngle: true), "the radial state shows an angle row")
        for (suffix, sample) in states {
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(sample, name: "suiteui-gradient-editor\(suffix)-\(scheme.name)", scheme: scheme)
            }
        }
    }
}

/// The editor in a Fill section on the panel colour, at the ideal inspector width.
private struct GradientEditorSample: View {
    let fill: Fill
    var selected = 0
    var refused = false

    var body: some View {
        InspectorSection("Fill") {
            GradientEditor(fill: fill, box: SuiteGradientEditorSnapshots.box, selected: selected, refused: refused) { _ in }
        }
        .padding(.vertical, SuiteSpacing.m)
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
