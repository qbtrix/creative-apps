// FlareFillSnapshots.swift: the inspector's FILL and STROKE sections (IT-5)
// from a paint readout: a solid FF3B30 fill, a gradient fill read only with
// its reason, a 4 pt stroke with Round cap and join, and the rows disabled
// with the window router's reason when nothing can be painted. The rows send
// through the `perform` they are given, never a focused scene value. Writes
// flare-fill-solid, flare-fill-gradient, flare-stroke and flare-fill-disabled
// PNGs.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareFillSnapshots {
    @Test func solid() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.selectLayer("ball")
        #expect(model.paint != nil, "Ball should have a paint readout, so FILL shows")
        let paint = PaintReadout(fillHex: "FF3B30", fillIsGradient: false, strokeHex: "000000", strokeWidth: 1,
                                 cap: .butt, join: .miter)
        try snapshot(Self.sections(paint), name: "flare-fill-solid", scheme: .light)
    }

    @Test func gradient() throws {
        let paint = PaintReadout(fillHex: nil, fillIsGradient: true, strokeHex: nil, strokeWidth: nil, cap: nil,
                                 join: nil)
        #expect(FlareInspectorFill.gradientReason.isEmpty == false)
        try snapshot(Self.sections(paint), name: "flare-fill-gradient", scheme: .light)
    }

    @Test func stroke() throws {
        let paint = PaintReadout(fillHex: "34C759", fillIsGradient: false, strokeHex: "1C1C1E", strokeWidth: 4,
                                 cap: .round, join: .round)
        try snapshot(Self.sections(paint), name: "flare-stroke", scheme: .dark)
    }

    @Test func disabledWithTheRoutersReason() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        let reason = FlareWindow.inspectorHelp(.setFill(hex: "FF3B30"), in: model)
        #expect(reason == "Select a layer to paint it.", "With no layer selected, FILL can't act")
        var sent: [FlareIntent] = []
        let fill = FlareInspectorFill(
            paint: Self.solidPaint, reasonFor: { FlareWindow.inspectorHelp($0, in: model) }, perform: { sent.append($0) })
        #expect(fill.reasonFor(.setStrokeWidth(2)) == reason)
        fill.perform(.inspector(.setFill(hex: "00FF00")))
        #expect(sent == [.inspector(.setFill(hex: "00FF00"))], "Rows send through the window's perform")
        try snapshot(Self.sections(Self.solidPaint, reasonFor: { FlareWindow.inspectorHelp($0, in: model) }),
                     name: "flare-fill-disabled", scheme: .dark)
    }

    private static let solidPaint = PaintReadout(
        fillHex: "FF3B30", fillIsGradient: false, strokeHex: "000000", strokeWidth: 1, cap: .butt, join: .miter)

    private static func sections(
        _ paint: PaintReadout, reasonFor: @escaping @MainActor (FlareIntent.Inspector) -> String? = { _ in nil }
    ) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            FlareInspectorFill(paint: paint, reasonFor: reasonFor, perform: { _ in })
        }
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
    }
}
