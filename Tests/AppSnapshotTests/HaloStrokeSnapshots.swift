// HaloStrokeSnapshots.swift (stroke-style HK-4): Halo's STROKE section
// (HaloStrokeInspector) in its states, from values since the Model's stroke is
// a stub until HK-6. A 4 pt stroke drawing the first 60% of the outline, its
// rows live (halo-stroke-editor); the same stroke with the trim rows' keys, Trim
// End keyed at the playhead and Trim Offset animated, so their diamonds show
// filled and hollow (halo-stroke-editor-trim-keyed). Light and Dark. macOS only.
import FlareCore
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloStrokeSnapshots {
    @Test func editor() throws {
        let section = HaloStrokeInspector(stroke: Self.stroke, help: nil)
        #expect(section.trimKeys.isEmpty, "no keys: the editor alone")
        try Self.both(Self.panel(section), name: "halo-stroke-editor")
    }

    @Test func trimKeyed() throws {
        let section = HaloStrokeInspector(stroke: Self.stroke, help: nil, trimKeys: Self.keys)
        let diamonds = section.trimKeys.compactMap { HaloPropertyRowView.keyState($0.keyState).diamond?.symbol }
        #expect(diamonds == ["diamond.fill", "diamond"], "End keyed here, Offset animated")
        try Self.both(Self.panel(section), name: "halo-stroke-editor-trim-keyed")
    }

    /// 4 pt, round join and cap, drawing 0 to 60%.
    private static let stroke = VectorStroke(width: 4, join: .round, cap: .round, trim: StrokeTrim(start: 0, end: 0.6))

    private static let keys = [
        HaloTrimKey(raw: "trimStart", title: "Trim Start", keyState: .notAnimated, help: nil),
        HaloTrimKey(raw: "trimEnd", title: "Trim End", keyState: .keyedHere, help: nil),
        HaloTrimKey(raw: "trimOffset", title: "Trim Offset", keyState: .animated, help: nil),
    ]

    private static func panel(_ section: HaloStrokeInspector) -> some View {
        section
            .padding(.vertical, SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
    }

    /// Writes `<name>-light` and `<name>-dark`.
    private static func both(_ view: some View, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
