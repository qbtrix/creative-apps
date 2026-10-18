// SuiteKeyframeSnapshots.swift: KeyframeButton beside a bar slider in each
// state (not animated, animated, keyed here with the keyed slider, disabled),
// on the editor panel, in Light and Dark. Writes suiteui-keyframe-light.png
// and suiteui-keyframe-dark.png, and checks the sheet against
// Golden/inspector/suiteui-keyframe-<appearance>.png in the four appearances
// (QB-V5; a known issue until IC-16 commits the baselines).
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteKeyframeSnapshots {
    @Test func keyframeStates() throws {
        try snapshot(KeyframeSheet(), name: "suiteui-keyframe-light", scheme: .light)
        try snapshot(KeyframeSheet(), name: "suiteui-keyframe-dark", scheme: .dark)
    }

    @Test func keyframeGoldens() {
        let size = CGSize(width: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.xxl, height: 240)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(KeyframeSheet(), size: size, name: "suiteui-keyframe", area: "inspector", appearance: appearance)
        }
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
        .environment(\.suiteReduceMotion, true)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func row(_ label: String, _ state: KeyState) -> some View {
        HStack(spacing: SuiteSpacing.xs) {
            InspectorSliderRow(label, value: 45, in: -180...180, unit: "°", decimals: 0, keyed: state == .keyedHere) { _ in }
            KeyframeButton(label, id: "suite.keyframe.\(label)", state: state, registers: true, onToggle: {}, onKey: {})
        }
    }
}
