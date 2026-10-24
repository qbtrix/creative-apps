// FlareFillSnapshots.swift: the inspector's FILL and STROKE sections (IT-5)
// from a paint readout: a solid FF3B30 fill, a 4 pt stroke with Round cap and
// join, and the rows disabled with the window router's reason when nothing can
// be painted. The rows send through the `perform` they are given, never a
// focused scene value. A switch that can't act shows its reason as a note, not
// only a tooltip. A gradient fill is FlareGradientSnapshots'. Writes
// flare-fill-solid, flare-stroke and flare-fill-disabled PNGs.
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

    @Test(.timeLimit(.minutes(1))) func anOffSwitchShowsItsReasonAsANote() async throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.selectLayer("ball")
        let paint = try #require(model.paint, "Ball should have a paint readout, so FILL shows")
        #expect(FlareWindow.inspectorHelp(.runFill(.type(.solid)), in: model) == nil, "Ball's fill can be edited (FG-5)")
        let reason = "Select a layer to paint it."
        let w = RenderBudgetWindow(Self.sections(paint, reasonFor: { _ in reason }))
        defer { w.close() }
        try await w.settle(500)
        #expect(await w.element(FlareInspectorFill.fillHelpID) != nil, "the off switch shows no note")
        #expect(w.label(FlareInspectorFill.fillHelpID) == reason, "the note isn't the router's reason")

        let open = RenderBudgetWindow(Self.sections(Self.solidPaint))
        defer { open.close() }
        try await open.settle(500)
        #expect(!open.identifiers().contains(FlareInspectorFill.fillHelpID), "a switch that can act shows a note")
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
            .frame(width: FlareWindow.inspectorWidth, alignment: .top)
            .background(SuiteColor.panel)
    }
}
