// SuiteToneRowsSnapshots.swift (tone-controls TC-4): ToneRows (TC-3) at the ideal inspector width on the panel
// colour, as an app's inspector hosts it, in Light and Dark. Writes suiteui-tone-rows-{light,dark}.png (every slider
// neutral: four sections, no Reset, Vibrance and Sharpen's Radius and Threshold off with their notes),
// suiteui-tone-rows-edited-{light,dark}.png (White Balance, Tone and Sharpen set: their Resets show, Radius and
// Threshold on), suiteui-tone-rows-vibrance-waiting-{light,dark}.png (PRESENCE alone: Vibrance off with
// ToneRules.waiting's reason under it) and suiteui-tone-rows-sharpen-off-{light,dark}.png (SHARPEN alone at Amount 0:
// Radius and Threshold off, "Sharpen is off at Amount 0." under them). macOS only.
import SuiteImaging
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteToneRowsSnapshots {
    @Test func toneRowsStates() throws {
        let edited = ToneSettings.neutral.setting(.temperature, to: 30).setting(.tint, to: -8)
            .setting(.highlights, to: -40).setting(.shadows, to: 35).setting(.sharpenAmount, to: 80)
        let all = Set(ToneSlider.allCases)
        let states: [(suffix: String, sample: ToneRowsSample)] = [
            ("", ToneRowsSample(settings: .neutral, hidden: [])),
            ("-edited", ToneRowsSample(settings: edited, hidden: [])),
            ("-vibrance-waiting", ToneRowsSample(settings: .neutral, hidden: all.subtracting(ToneGroup.presence.sliders))),
            ("-sharpen-off", ToneRowsSample(settings: .neutral, hidden: all.subtracting(ToneGroup.sharpen.sliders))),
        ]
        #expect([ToneGroup.whiteBalance, .tone, .sharpen].allSatisfy {
            ToneRowsRules(settings: edited, help: nil, hidden: []).reset($0) != nil
        }, "the edited state doesn't show its Resets")
        for (suffix, sample) in states {
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(sample, name: "suiteui-tone-rows\(suffix)-\(scheme.name)", scheme: scheme)
            }
        }
    }
}

/// The rows on the panel colour, at the ideal inspector width.
private struct ToneRowsSample: View {
    let settings: ToneSettings
    let hidden: Set<ToneSlider>

    var body: some View {
        ToneRows(settings: settings, help: nil, hidden: hidden) { _ in }
            .padding(.vertical, SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
