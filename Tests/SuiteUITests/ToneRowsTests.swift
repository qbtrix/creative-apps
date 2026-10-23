// ToneRowsTests.swift: SuiteUI's ToneRows (tone-controls TC-3) through ToneRowsRules, the decisions its rows make.
// A drag asks for `.set`s under one drag token, and the next drag for a new one; a typed value asks for one `.set`;
// Auto asks for `.auto`; a section's Reset asks for `.reset(group)` and shows only off neutral; Vibrance is disabled
// with ToneRules.waiting's reason; Radius and Threshold are off at Amount 0 with "Sharpen is off at Amount 0."; `help`
// and no settings disable every control. No rendering. macOS only.
import SuiteImaging
import Testing

@testable import SuiteUI

private func rules(_ settings: ToneSettings? = .neutral, help: String? = nil, hidden: Set<ToneSlider> = []) -> ToneRowsRules {
    ToneRowsRules(settings: settings, help: help, hidden: hidden)
}

/// A drag as the view runs it: the open token (opened on the first sample), then the sample's intent.
private func drag(_ values: [Double], _ intent: (Double, String) -> ToneIntent?) -> [ToneIntent] {
    var open: String?
    return values.compactMap { value in
        let token = ToneRowsRules.token(open)
        open = token
        return intent(value, token)
    }
}

private func tokens(_ intents: [ToneIntent]) -> Set<String> {
    Set(intents.compactMap { intent -> String? in
        if case .set(_, _, let drag) = intent { return drag }
        return nil
    })
}

@Test func aDragAsksForSetsUnderOneToken() {
    let rows = rules()
    let first = drag([0, 5, 10, 30]) { rows.set(.temperature, to: $0, drag: $1) }
    #expect(first.count == 3) // the sample on the value already shown asks for nothing
    #expect(tokens(first).count == 1)
    #expect(first.last.map { if case .set(.temperature, 30, _) = $0 { true } else { false } } == true)
    let second = drag([31]) { rows.set(.temperature, to: $0, drag: $1) }
    #expect(second.count == 1)
    #expect(tokens(second).isDisjoint(with: tokens(first)))
}

@Test func aTypedValueAsksForOneSet() {
    let typed = drag([35]) { rules().set(.shadows, to: $0, drag: $1) }
    #expect(typed.count == 1)
    #expect(typed.first.map { if case .set(.shadows, 35, _) = $0 { true } else { false } } == true)
    #expect(rules().set(.shadows, to: .nan, drag: nil) == nil)
}

@Test func autoAsksForAuto() {
    #expect(rules().auto == .auto)
    #expect(rules().autoReason == nil)
    #expect(rules(nil).auto == nil)
    #expect(rules(nil).autoReason == ToneRowsRules.nothing)
    #expect(rules(help: "Open a picture.").auto == nil)
}

@Test func aSectionResetShowsOnlyOffNeutral() {
    #expect(ToneGroup.allCases.allSatisfy { rules().reset($0) == nil })
    let edited = ToneSettings.neutral.setting(.shadows, to: 35)
    #expect(rules(edited).reset(.tone) == .reset(.tone))
    #expect(rules(edited).reset(.whiteBalance) == nil)
    #expect(rules(edited, help: "Busy.").reset(.tone) == nil)
}

@Test func vibranceWaitsWithItsReason() {
    let reason = ToneRules.waiting[.vibrance]
    #expect(reason != nil)
    #expect(rules().reason(.vibrance) == reason)
    #expect(rules().set(.vibrance, to: 20, drag: nil) == nil)
    #expect(rules().notes(.presence) == [reason].compactMap { $0 })
    #expect(rules().reason(.saturation) == nil)
}

@Test func radiusAndThresholdAreOffAtAmountZero() {
    for slider in [ToneSlider.sharpenRadius, .sharpenThreshold] {
        #expect(rules().reason(slider) == "Sharpen is off at Amount 0.")
        #expect(rules().set(slider, to: 2, drag: nil) == nil)
        #expect(rules(ToneSettings.neutral.setting(.sharpenAmount, to: 80)).reason(slider) == nil)
    }
    #expect(rules().reason(.sharpenAmount) == nil)
}

@Test func helpAndNoSettingsDisableEveryRow() {
    #expect(ToneSlider.allCases.allSatisfy { rules(help: "Busy.").reason($0) == "Busy." })
    #expect(ToneSlider.allCases.allSatisfy { rules(nil).reason($0) == ToneRowsRules.nothing })
    #expect(rules(nil).notes(.presence).isEmpty) // the one reason shows once, above the sections
}

@Test func hiddenSlidersAndEmptySectionsDrop() {
    let photo = rules(hidden: [.exposure])
    #expect(!photo.sliders(.tone).contains(.exposure))
    #expect(photo.groups == ToneGroup.allCases)
    #expect(rules(hidden: [.temperature, .tint]).groups == [.tone, .presence, .sharpen])
}

@Test func rowsShowTheirStepsPlaces() {
    #expect(ToneRowsRules.decimals(.exposure) == 2)
    #expect(ToneRowsRules.decimals(.sharpenRadius) == 1)
    #expect(ToneRowsRules.decimals(.shadows) == 0)
    #expect(ToneRowsRules.identifier(.sharpenAmount) == "suite.tone.sharpenAmount")
}
