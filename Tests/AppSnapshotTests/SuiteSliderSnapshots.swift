// SuiteSliderSnapshots.swift: the bar slider's contact sheet, one row per
// state (rest, hover, focus, dragging, editing, disabled, keyed, mixed, an
// empty and a full fill, a non-linear track) and the exact-number ScrubField
// at rest and focused, on the editor panel, in Light and Dark. Writes
// suiteui-slider-light.png and suiteui-slider-dark.png. Live states are
// seeded through ScrubField.Bar's preview, so the sheet needs no events.
// The log-mapped Gamma row (#88) is also a golden in the four appearances,
// Golden/inspector/suiteui-slider-log-<appearance>.png: value 1 over
// 0.1...10 on a log10 track draws its marker at the middle and reads "1".
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteSliderSnapshots {
    @Test func sliderStates() throws {
        try snapshot(SliderSheet(), name: "suiteui-slider-light", scheme: .light)
        try snapshot(SliderSheet(), name: "suiteui-slider-dark", scheme: .dark)
    }

    /// #88: the field shows the value (1), the bar its log10 position (the
    /// middle), from the same rules the row draws with.
    @Test func logMappedRowSitsMidTrackAndReadsOne() {
        let track = LogRow.track
        #expect(ScrubValue.fraction(track.position(1), in: track.positions) == 0.5)
        #expect(NumericInput.text(1, decimals: 0) == "1")
        #expect(track.value(track.position(1)) == 1)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(
                LogRow(), size: CGSize(width: SuiteSize.editorPanelWidth, height: SuiteSize.studioRow + 2 * SuiteSpacing.m),
                name: "suiteui-slider-log", area: "inspector", appearance: appearance)
        }
    }
}

/// Photo's Gamma shape: value 1 over 0.1...10 on a log10 track in -1...1,
/// with a ±4-step detent at 1 that its `stepped` steps out of (#591).
private struct LogRow: View {
    static let track = ScrubTrack(
        positions: -1...1, step: 0.01, position: { log10($0) }, value: { abs($0) <= 0.04 ? 1 : pow(10, $0) },
        stepped: { position, delta in
            position == 0 && abs(delta) <= 0.04 ? (delta > 0 ? 0.04 : -0.04) + delta : position + delta
        })

    var body: some View {
        InspectorSliderRow("Gamma", value: 1, in: 0.1...10, decimals: 0, track: Self.track) { _ in }
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SuiteColor.panel)
    }
}

private struct SliderSheet: View {
    private typealias Bar = ScrubField.Bar

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            column([
                ("Rest", Bar()), ("Hover", Bar(preview: .hover)), ("Focus", Bar(preview: .focus)),
                ("Dragging", Bar(preview: .dragging)), ("Editing", Bar(preview: .editing)),
            ])
            column([("Keyed", Bar(keyed: true)), ("Mixed", Bar(mixed: true))]) {
                InspectorSliderRow("Disabled", value: 45, in: -180...180, unit: "°", decimals: 0) { _ in }.disabled(true)
                InspectorSliderRow("Opacity", value: 0, in: 0...100, unit: "%", decimals: 0) { _ in }
                InspectorSliderRow("Scale", value: 4, in: 0.25...4, unit: "×") { _ in }
                InspectorSliderRow("Gamma", value: 1, in: 0.1...10, decimals: 0, track: LogRow.track) { _ in }
                ScrubField("Position X", value: 960, in: -9999...9999, unit: "px", decimals: 1) { _ in }
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    /// Rotation rows at 45° in each state, then `extra`, at the panel's width.
    private func column(_ states: [(String, Bar)], @ViewBuilder extra: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.row) {
            ForEach(states, id: \.0) { title, bar in
                InspectorSliderRow(
                    title, value: 45, in: -180...180, step: nil, unit: "°", decimals: 0, bar: bar, onChange: { _ in },
                    onEnd: {})
            }
            extra()
        }
        .frame(width: SuiteSize.editorPanelWidth - 2 * SuiteSpacing.m)
    }
}
