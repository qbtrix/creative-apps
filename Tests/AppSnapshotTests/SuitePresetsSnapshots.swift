// SuitePresetsSnapshots.swift: the preset grid (two columns, one on), the
// three-column ChoiceChips built on it (seven presets, a short last row), toggle
// chips on and off with and without symbols, a disabled preset, and
// InspectorAction enabled and disabled, on the editor panel, in Light and
// Dark. Writes suiteui-presets-light.png and suiteui-presets-dark.png, and
// checks the presets and the chips against Golden/inspector/presets-<appearance>.png
// and Golden/inspector/chips-<appearance>.png in the four appearances
// (IC-16 and IC-17 commit the baselines).
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuitePresetsSnapshots {
    @Test func presetsChipsAndActions() throws {
        try snapshot(PresetsSheet(), name: "suiteui-presets-light", scheme: .light)
        try snapshot(PresetsSheet(), name: "suiteui-presets-dark", scheme: .dark)
    }

    @Test func presetsGolden() {
        let size = CGSize(width: SuiteSize.editorPanelWidth, height: 150)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(PresetsCard(), size: size, name: "presets", area: "inspector", appearance: appearance)
        }
    }

    @Test func chipsGolden() {
        let size = CGSize(width: SuiteSize.editorPanelWidth, height: 60)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(ChipsCard(), size: size, name: "chips", area: "inspector", appearance: appearance)
        }
    }
}

private let easings = ["Linear", "Ease", "Ease In", "Ease Out", "Ease In-Out", "Hold"]
    .map { InspectorOption(id: $0, title: $0) }

/// Seven presets for ChoiceChips' three columns: a last row of one.
private let sevenEasings = easings + [InspectorOption(id: "Spring", title: "Spring")]

private let toggleChips = [
    ChipItem(id: 0, title: "Onion", systemImage: "circle.dotted", isOn: true),
    ChipItem(id: 1, title: "Loop", systemImage: "repeat", isOn: false),
    ChipItem(id: 2, title: "Snap", isOn: false),
]

/// The two-column grid with one on, and the seven-preset ChoiceChips with "Ease Out" on.
private struct PresetsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            PresetGrid(options: easings, selected: "Ease In") { _ in }
            ChoiceChips(options: sevenEasings, selected: "Ease Out") { _ in }
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }
}

/// The toggle chips, one on.
private struct ChipsCard: View {
    var body: some View {
        ChipRow(toggleChips) { _ in }
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SuiteColor.panel)
    }
}

private struct PresetsSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            PresetGrid(options: easings, selected: "Ease In") { _ in }
            ChoiceChips(options: sevenEasings, selected: "Ease") { _ in }
            PresetGrid(options: Array(easings.prefix(2)), selected: nil) { _ in }.disabled(true)
            ChipRow(toggleChips) { _ in }
            InspectorAction(ToolbarAction("Extract Audio", systemImage: "waveform"))
            InspectorAction(ToolbarAction("Apply Crop", systemImage: "crop", unavailableHelp: "Drag a crop first."))
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.editorPanelWidth)
        .background(SuiteColor.panel)
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
