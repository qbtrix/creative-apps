// PhotoToneSnapshots.swift (tone-controls PT-2, PT-5): Photo's Adjust panel
// with the suite's tone rows (White Balance, Tone, Presence, Sharpen) under
// its own Exposure section, Exposure dropped from the rows so it shows once,
// and the rows on (no help) with an image open (PT-4), at the inspector's
// ideal width, in Light and Dark. Writes photo-tone-panel-light.png and
// photo-tone-panel-dark.png. layerPanel is a Levels adjustment layer's panel
// (tone-controls step 4): Levels first, the tone rows under it, Sharpen off
// with its help. Writes photo-adjust-tone-layer-light.png and -dark.png.
// macOS only.
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoToneSnapshots {
    @Test func panel() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        let sample = ToneSample(settings: model.adjustments, help: model.toneHelp)
        #expect(sample.help == nil, "with an image open the rows are on")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(sample, name: "photo-tone-panel-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func layerPanel() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 64)
        model.addAdjustmentLayer(.levels)
        #expect(!model.toneRowsLead, "a Levels layer shows Levels first")
        let rowHelp = AdjustmentsPanel.toneRowHelp(model)
        #expect(!rowHelp.isEmpty, "Sharpen is off on a layer and says why")
        guard case .layer(_, let settings) = model.adjustTarget else {
            Issue.record("the new layer is the adjust target")
            return
        }
        let sample = ToneSample(
            settings: settings, help: model.toneHelp, sections: model.adjustSections,
            showsEnable: AdjustmentsPanel.showsEnable(for: model.adjustTarget), rowHelp: rowHelp)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(sample, name: "photo-adjust-tone-layer-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct ToneSample: View {
    let settings: AdjustmentSettings
    let help: String?
    var sections: [AdjustmentKind] = [.exposure]
    var showsEnable = true
    var rowHelp: [ToneSlider: String] = [:]
    var body: some View {
        AdjustmentsInspector(settings: settings, sections: sections, showsEnable: showsEnable, toneHelp: help, toneRowHelp: rowHelp)
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
