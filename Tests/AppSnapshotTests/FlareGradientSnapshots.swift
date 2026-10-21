// FlareGradientSnapshots.swift (gradient-fill FG-2, FG-3): the inspector's FILL section on a gradient. It shows the
// Solid / Linear / Radial switch on Linear and SuiteUI's GradientEditor with the fill's three stops, never the word
// "Gradient" with a refusal. The editor's gestures go out as `.inspector(.runFill(_))` through the window's perform.
// Writes flare-fill-gradient in Light and Dark.
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareGradientSnapshots {
    @Test func fillGradient() throws {
        let paint = Self.gradientPaint
        #expect(paint.gradient.map { GradientRules.type(of: $0.fill) } == .linear, "The readout carries the gradient")
        #expect(FlareInspectorFill.fillTypes.map(\.id) == FillType.allCases, "FILL offers Solid, Linear and Radial")
        var sent: [FlareIntent] = []
        let fill = FlareInspectorFill(paint: paint, reasonFor: { _ in nil }, perform: { sent.append($0) })
        fill.perform(.inspector(.runFill(.type(.radial))))
        #expect(sent == [.inspector(.runFill(.type(.radial)))], "A switch pick goes out as the fill command")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.section(paint), name: "flare-fill-gradient-\(scheme.name)", scheme: scheme)
        }
    }

    /// A three-stop left-to-right linear fill across a 0...100 box.
    private static let gradientPaint: PaintReadout = {
        let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
        let stops = [GradientStop(offset: 0, color: FillColor(r: 1, g: 0.23, b: 0.19)),
                     GradientStop(offset: 0.5, color: FillColor(r: 1, g: 0.8, b: 0)),
                     GradientStop(offset: 1, color: FillColor(r: 0, g: 0.48, b: 1))]
        let fill = Fill.linear(stops: stops, start: Point(x: 0, y: 50), end: Point(x: 100, y: 50))
        return PaintReadout(fillHex: nil, fillIsGradient: true, strokeHex: "000000", strokeWidth: 1, cap: .butt,
                            join: .miter, gradient: FillSelection(fill: fill, box: box))
    }()

    private static func section(_ paint: PaintReadout) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            FlareInspectorFill(paint: paint, reasonFor: { _ in nil }, perform: { _ in })
        }
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
    }
}
