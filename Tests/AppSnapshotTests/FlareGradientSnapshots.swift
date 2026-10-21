// FlareGradientSnapshots.swift (gradient-fill FG-2, FG-3): the inspector's FILL section in each of its states. On a
// gradient it shows the Solid / Linear / Radial switch and SuiteUI's GradientEditor with the fill's three stops, never
// the word "Gradient" with a refusal, and the editor shows no second type switch of its own. A radial fill has no
// angle; a solid fill is the switch on Solid over the colour row; while nothing can be painted the switch and the
// editor are off with the router's reason. The editor's gestures go out as `.inspector(.runFill(_))` through the
// window's perform. Writes flare-fill-gradient, flare-fill-radial, flare-fill-solid-switch and
// flare-fill-gradient-disabled in Light and Dark.
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
        let fill = try #require(paint.gradient?.fill)
        #expect(FlareInspectorFill.editorTypes(fill).count == 1, "The editor shows no second type switch under FILL's")
        var sent: [FlareIntent] = []
        let section = FlareInspectorFill(paint: paint, reasonFor: { _ in nil }, perform: { sent.append($0) })
        section.perform(.inspector(.runFill(.type(.radial))))
        #expect(sent == [.inspector(.runFill(.type(.radial)))], "A switch pick goes out as the fill command")
        try Self.both(Self.section(paint), name: "flare-fill-gradient")
    }

    @Test func fillRadial() throws {
        let fill = try #require(Self.radialPaint.gradient?.fill)
        #expect(GradientRules.type(of: fill) == .radial, "The readout carries a radial fill")
        #expect(GradientRules.angle(of: fill) == nil, "A radial fill has no angle, so no angle row")
        try Self.both(Self.section(Self.radialPaint), name: "flare-fill-radial")
    }

    @Test func fillSolidSwitch() throws {
        let paint = PaintReadout(fillHex: "FF3B30", fillIsGradient: false, strokeHex: "000000", strokeWidth: 1,
                                 cap: .butt, join: .miter)
        #expect(paint.gradient == nil, "A solid fill shows the colour row, not the editor")
        try Self.both(Self.section(paint), name: "flare-fill-solid-switch")
    }

    @Test func fillGradientDisabled() throws {
        let reason = "Select a layer to paint it."
        let section = FlareInspectorFill(paint: Self.gradientPaint, reasonFor: { _ in reason }, perform: { _ in })
        #expect(section.reasonFor(.runFill(.type(.solid))) == reason, "The switch and the editor carry the reason")
        try Self.both(Self.section(Self.gradientPaint, reasonFor: { _ in reason }), name: "flare-fill-gradient-disabled")
    }

    /// The box the fixtures' points are in.
    private static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)

    /// Red, yellow and blue at 0, 50% and 100%.
    private static let stops = [GradientStop(offset: 0, color: FillColor(r: 1, g: 0.23, b: 0.19)),
                                GradientStop(offset: 0.5, color: FillColor(r: 1, g: 0.8, b: 0)),
                                GradientStop(offset: 1, color: FillColor(r: 0, g: 0.48, b: 1))]

    /// The three stops left to right across the box.
    private static let gradientPaint = paint(.linear(stops: stops, start: Point(x: 0, y: 50), end: Point(x: 100, y: 50)))

    /// The same stops from the box's centre out to its edge.
    private static let radialPaint = paint(.radial(stops: stops, center: Point(x: 50, y: 50), radius: 50))

    private static func paint(_ fill: Fill) -> PaintReadout {
        PaintReadout(fillHex: nil, fillIsGradient: true, strokeHex: "000000", strokeWidth: 1, cap: .butt,
                     join: .miter, gradient: FillSelection(fill: fill, box: box))
    }

    /// Writes `<name>-light` and `<name>-dark`.
    private static func both(_ view: some View, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }

    private static func section(
        _ paint: PaintReadout, reasonFor: @escaping @MainActor (FlareIntent.Inspector) -> String? = { _ in nil }
    ) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            FlareInspectorFill(paint: paint, reasonFor: reasonFor, perform: { _ in })
        }
            .padding(SuiteSpacing.m)
            .frame(width: FlareWindow.inspectorWidth, alignment: .top)
            .background(SuiteColor.panel)
    }
}
