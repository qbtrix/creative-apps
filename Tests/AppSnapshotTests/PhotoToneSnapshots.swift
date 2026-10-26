// PhotoToneSnapshots.swift (tone-controls PT-2, PT-5): Photo's Adjust panel
// with the suite's tone rows (White Balance, Tone, Presence, Sharpen) under
// its own Exposure section, Exposure dropped from the rows so it shows once,
// and the rows on (no help) with an image open (PT-4), at the inspector's
// ideal width, in Light and Dark. Writes photo-tone-panel-light.png and
// photo-tone-panel-dark.png. macOS only.
import PhotoModel
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
}

private struct ToneSample: View {
    let settings: AdjustmentSettings
    let help: String?
    var body: some View {
        AdjustmentsInspector(settings: settings, sections: [.exposure], toneHelp: help)
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
