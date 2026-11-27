// SuiteToneRowsSnapshots.swift (tone-controls TC-4): ToneRows in an inspector, Light and Dark: suiteui-tone-rows
// (neutral), -edited (three Resets show), -vibrance-waiting (PRESENCE alone), -sharpen-off (SHARPEN at Amount 0) and
// -sharpen-host-off (SHARPEN off by the host's own reason, Photo's adjustment layer).
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
            ("-sharpen-host-off", ToneRowsSample(
                settings: .neutral.setting(.sharpenAmount, to: 40), hidden: all.subtracting(ToneGroup.sharpen.sliders),
                rowHelp: Dictionary(uniqueKeysWithValues: ToneGroup.sharpen.sliders.map { ($0, "Sharpen is for the image.") }))),
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
    var rowHelp: [ToneSlider: String] = [:]

    var body: some View {
        ToneRows(settings: settings, help: nil, hidden: hidden, rowHelp: rowHelp) { _ in }
            .padding(.vertical, SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
