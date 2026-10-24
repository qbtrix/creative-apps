// ToneRows.swift: SuiteUI's one set of tone and sharpen rows (packet
// docs/blueprints/suiteui/features/tone-controls.md). It takes one picture's
// ToneSettings in and reports every change out through `onIntent` as a
// ToneIntent, which the app runs as a tone command; it never edits a document
// or reads a Model. TC-2 is a placeholder that lists the four sections
// (White Balance, Tone, Presence, Sharpen) and each slider's title and value,
// with no controls yet; TC-3 builds the view: InspectorSection per group with
// its Reset, InspectorSliderRow per slider (`suite.tone.<slider>`), Auto
// (`suite.tone.auto`), and the waiting and off states with their help.
import SuiteImaging
import SwiftUI

/// `hidden` drops sliders an app shows elsewhere (Photo keeps its own Exposure section).
public struct ToneRows: View {
    let settings: ToneSettings?
    let help: String?
    let hidden: Set<ToneSlider>
    let onIntent: (ToneIntent) -> Void

    public init(
        settings: ToneSettings?, help: String?, hidden: Set<ToneSlider> = [],
        onIntent: @escaping (ToneIntent) -> Void
    ) {
        self.settings = settings
        self.help = help
        self.hidden = hidden
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            if let help {
                Text(help).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
            ForEach(ToneGroup.allCases, id: \.self) { group in
                let sliders = ToneRowsText.visible(group, hidden: hidden)
                if !sliders.isEmpty {
                    VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                        Text(group.title.uppercased())
                            .font(SuiteFont.sectionCaps)
                            .foregroundStyle(SuiteColor.secondaryText)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(sliders, id: \.self) { slider in
                            Text(ToneRowsText.row(slider, settings: settings))
                                .font(SuiteFont.body)
                                .foregroundStyle(settings == nil ? SuiteColor.secondaryText : SuiteColor.textPrimary)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.tone")
    }
}

/// The placeholder's text, kept out of the body so TC-3's rows can reuse it.
enum ToneRowsText {
    /// The group's sliders in row order, without the hidden ones.
    static func visible(_ group: ToneGroup, hidden: Set<ToneSlider>) -> [ToneSlider] {
        group.sliders.filter { !hidden.contains($0) }
    }

    /// "Shadows, 35"; a slider with no settings reads its neutral value.
    static func row(_ slider: ToneSlider, settings: ToneSettings?) -> String {
        "\(slider.title), \(value(settings?.value(slider) ?? slider.neutral, step: slider.step))"
    }

    /// A whole step shows no decimals; Exposure two, Radius one.
    static func value(_ v: Double, step: Double) -> String {
        guard v.isFinite else { return "0" }
        let places = step < 0.1 ? 2 : step < 1 ? 1 : 0
        return v.formatted(.number.precision(.fractionLength(places)))
    }
}
