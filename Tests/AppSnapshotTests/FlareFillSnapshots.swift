// FlareFillSnapshots.swift: the inspector's FILL and STROKE sections (IT-5)
// from a paint readout: a solid FF3B30 fill, a gradient fill read only with
// its reason, and a 4 pt stroke with Round cap and join. With no window
// focused the controls are enabled and send nothing. Writes flare-fill-solid,
// flare-fill-gradient and flare-stroke PNGs.
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

    private static func sections(_ paint: PaintReadout) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) { FlareInspectorFill(paint: paint) }
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
    }
}
