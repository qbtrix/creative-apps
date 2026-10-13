// SuiteKeyframeSnapshots.swift: KeyframeButton beside a bar slider in each
// state (not animated, animated, keyed here with the keyed slider, disabled),
// on the editor panel, in Light and Dark. Writes suiteui-keyframe-light.png
// and suiteui-keyframe-dark.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteKeyframeSnapshots {
    @Test func keyframeStates() throws {
        try snapshot(KeyframeSheet(), name: "suiteui-keyframe-light", scheme: .light)
        try snapshot(KeyframeSheet(), name: "suiteui-keyframe-dark", scheme: .dark)
    }
}

private struct KeyframeSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.row) {
            row("Opacity", .idle)
            row("Rotation", .animated)
            row("Scale", .keyedHere)
            row("Skew", .animated).disabled(true)
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.editorPanelWidth)
        .background(SuiteColor.panel)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ label: String, _ state: KeyState) -> some View {
        HStack(spacing: SuiteSpacing.xs) {
            InspectorSliderRow(label, value: 45, in: -180...180, unit: "°", decimals: 0, keyed: state == .keyedHere) { _ in }
            KeyframeButton(label, state: state, onToggle: {}, onKey: {})
        }
    }
}
