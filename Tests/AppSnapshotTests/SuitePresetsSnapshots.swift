// SuitePresetsSnapshots.swift: the preset grid (two columns, one on), the
// three-column ChoiceChips built on it, toggle chips on and off with and
// without symbols, a disabled preset, and InspectorAction enabled and
// disabled, on the editor panel, in Light and Dark. Writes
// suiteui-presets-light.png and suiteui-presets-dark.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuitePresetsSnapshots {
    @Test func presetsChipsAndActions() throws {
        try snapshot(PresetsSheet(), name: "suiteui-presets-light", scheme: .light)
        try snapshot(PresetsSheet(), name: "suiteui-presets-dark", scheme: .dark)
    }
}

private struct PresetsSheet: View {
    private let easings = ["Linear", "Ease", "Ease In", "Ease Out", "Ease In-Out", "Hold"]
        .map { InspectorOption(id: $0, title: $0) }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            PresetGrid(options: easings, selected: "Ease In") { _ in }
            ChoiceChips(options: easings, selected: "Ease") { _ in }
            PresetGrid(options: Array(easings.prefix(2)), selected: nil) { _ in }.disabled(true)
            ChipRow([
                ChipItem(id: 0, title: "Onion", systemImage: "circle.dotted", isOn: true),
                ChipItem(id: 1, title: "Loop", systemImage: "repeat", isOn: false),
                ChipItem(id: 2, title: "Snap", isOn: false),
            ]) { _ in }
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
