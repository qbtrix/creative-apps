// ToneRows.swift: SuiteUI's one set of tone and sharpen rows (packet
// docs/blueprints/suiteui/features/tone-controls.md). It takes one picture's
// ToneSettings in and reports every change out through `onIntent` as a
// ToneIntent, which the app runs as a tone command; it never edits a document
// or reads a Model. TC-3: an InspectorSection per group, its Reset only off
// neutral; an InspectorSliderRow per slider (`suite.tone.<slider>`) whose drag
// sends one `.set` per sample under one drag token; Auto (`suite.tone.auto`).
// A row that can't act is disabled with its reason as help (ToneRowsRules,
// which ToneRowsTests drive; the shared reason shows once above, the others
// once under their section).
import Foundation
import SuiteImaging
import SwiftUI

/// `hidden` drops sliders an app shows elsewhere (Photo keeps its own Exposure section).
public struct ToneRows: View {
    private let rules: ToneRowsRules
    /// Called once per gesture sample with its intent.
    private let onIntent: @MainActor (ToneIntent) -> Void
    /// The open drag's token; nil between gestures.
    @State private var drag: String?

    public init(
        settings: ToneSettings?, help: String?, hidden: Set<ToneSlider> = [],
        onIntent: @escaping @MainActor (ToneIntent) -> Void
    ) {
        rules = ToneRowsRules(settings: settings, help: help, hidden: hidden)
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            if let reason = rules.autoReason { InspectorNote(reason).padding(.horizontal, SuiteSpacing.m) }
            ForEach(rules.groups, id: \.self) { group in
                InspectorSection(group.title, onReset: resetAction(group)) {
                    ForEach(rules.sliders(group), id: \.self) { row($0) }
                    ForEach(rules.notes(group), id: \.self) { InspectorNote($0) }
                    if group == .tone { auto }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.tone")
    }

    /// The section's Reset while the group is off neutral; nil hides it.
    private func resetAction(_ group: ToneGroup) -> (@MainActor () -> Void)? {
        guard let intent = rules.reset(group) else { return nil }
        let onIntent = onIntent
        return { onIntent(intent) }
    }

    private func row(_ slider: ToneSlider) -> some View {
        let reason = rules.reason(slider)
        let id = ToneRowsRules.identifier(slider)
        return InspectorSliderRow(
            slider.title, value: rules.value(slider), in: slider.range, step: slider.step,
            decimals: ToneRowsRules.decimals(slider),
            onChange: { v in sample { rules.set(slider, to: v, drag: $0) } }, onEnd: end)
            .disabled(reason != nil)
            .help(reason ?? "")
            .suiteControl(id: id, enabled: reason == nil, reason: reason)
    }

    private var auto: some View {
        InspectorAction(ToolbarAction(
            "Auto", systemImage: "wand.and.stars", unavailableHelp: rules.autoReason,
            identifier: "suite.tone.auto") { if let intent = rules.auto { onIntent(intent) } })
    }

    /// One gesture sample: the open token (opened on the first sample), then the one intent it asks for.
    private func sample(_ intent: (String) -> ToneIntent?) {
        let token = ToneRowsRules.token(drag)
        if drag == nil { drag = token }
        if let intent = intent(token) { onIntent(intent) }
    }

    private func end() { if drag != nil { drag = nil } }
}

/// What the rows show and ask for: which sections and rows, why one can't act, each row's value, and the one
/// intent a gesture asks for (nil when the control can't act or the sample changes nothing).
struct ToneRowsRules: Sendable {
    let settings: ToneSettings?
    let help: String?
    let hidden: Set<ToneSlider>

    nonisolated static let nothing = "No picture to adjust."
    nonisolated static let sharpenOff = "Sharpen is off at Amount 0."

    /// The sections with at least one shown row, in order.
    var groups: [ToneGroup] { ToneGroup.allCases.filter { !sliders($0).isEmpty } }

    /// The group's sliders in row order, without the hidden ones.
    func sliders(_ group: ToneGroup) -> [ToneSlider] { group.sliders.filter { !hidden.contains($0) } }

    func value(_ slider: ToneSlider) -> Double { settings?.value(slider) ?? slider.neutral }

    /// Why every control is off: `help`, or no settings; nil when they can act. Auto's reason too.
    var autoReason: String? { help ?? (settings == nil ? Self.nothing : nil) }

    /// Why the slider's row can't act; nil when it can.
    func reason(_ slider: ToneSlider) -> String? {
        if let all = autoReason { return all }
        if let waiting = ToneRules.waiting[slider] { return waiting }
        let needsAmount = slider == .sharpenRadius || slider == .sharpenThreshold
        return needsAmount && value(.sharpenAmount) == 0 ? Self.sharpenOff : nil
    }

    /// The group's row reasons, once each, under its rows; the reason every row shares shows above instead.
    func notes(_ group: ToneGroup) -> [String] {
        guard autoReason == nil else { return [] }
        var seen: [String] = []
        for reason in sliders(group).compactMap(reason) where !seen.contains(reason) { seen.append(reason) }
        return seen
    }

    /// The sample's `.set`; nil when the row can't act, or for a value that isn't finite or is already shown.
    func set(_ slider: ToneSlider, to v: Double, drag: String?) -> ToneIntent? {
        guard reason(slider) == nil, v.isFinite, v != value(slider) else { return nil }
        return .set(slider, v, drag: drag)
    }

    /// The section's Reset, only while the group is off neutral and the controls can act.
    func reset(_ group: ToneGroup) -> ToneIntent? {
        guard autoReason == nil, settings?.isNeutral(group) == false else { return nil }
        return .reset(group)
    }

    var auto: ToneIntent? { autoReason == nil ? .auto : nil }

    /// The open gesture's token, or a new one for its first sample.
    nonisolated static func token(_ open: String?) -> String { open ?? UUID().uuidString }

    /// A whole step shows no decimals; Exposure two, Radius one.
    nonisolated static func decimals(_ slider: ToneSlider) -> Int { slider.step < 0.1 ? 2 : slider.step < 1 ? 1 : 0 }

    nonisolated static func identifier(_ slider: ToneSlider) -> String { "suite.tone.\(slider.rawValue)" }
}
