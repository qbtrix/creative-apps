// OnboardingStartPage.swift: the welcome window's page 3, the starter row
// (onboarding packet OB-4). One grid row per starter in the model's focus
// order: the app's mark and name, its presets as ChoiceChips titled "New ..."
// (SuiteOnboarding.presetTitle; a chip creates that document at once, as the home's tiles do) and "Open sample", disabled
// with the model's reason as its help when the sample isn't in this build.
// While a hand-off is in flight its row shows a small progress ring and every
// control is disabled; a refused hand-off's sentence sits under that row,
// never an alert. "Start from an empty home" is the window's default button
// on this page (OnboardingWindow.swift). The view reads the model and calls
// its methods only.
import Foundation
import SuiteModel
import SuiteUI
import SwiftUI

struct OnboardingStartPage: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Grid(alignment: .leading, horizontalSpacing: SuiteSpacing.m, verticalSpacing: SuiteSpacing.s) {
                ForEach(model.starters, id: \.tile.app) { starter in
                    row(starter)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.launching == nil, let message = model.message {
                Text(message.message).font(SuiteFont.caption).foregroundStyle(SuiteColor.stateWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// One starter: the app's mark and name, its preset chips (and the in-place message), Open sample.
    private func row(_ starter: OnboardingStarter) -> some View {
        let app = starter.tile.app
        let busy = model.launching != nil
        let sampleEnabled = starter.sample != nil && starter.sampleReason == nil && !busy
        return GridRow(alignment: .center) {
            HStack(spacing: SuiteSpacing.s) {
                AppMark(app: app, style: .line).symbolSized().font(SuiteFont.body)
                Text(app.displayName).font(SuiteFont.body).foregroundStyle(SuiteColor.textPrimary)
                if model.launching == app {
                    ProgressView().controlSize(.small).accessibilityLabel("Opening \(app.displayName)")
                }
            }
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                presets(starter.tile, busy: busy)
                if model.launching == app, let message = model.message {
                    Text(message.message).font(SuiteFont.caption).foregroundStyle(SuiteColor.stateWarning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Open sample") { Task { await model.openSample(app, now: Date()) } }
                .disabled(!sampleEnabled)
                .help(starter.sampleReason ?? starter.sample.map { "Open \($0.title) in \(app.displayName)." }
                    ?? "The \(app.displayName) sample isn't in this build.")
                .suiteControl(id: OnboardingControls.sample(app), enabled: sampleEnabled,
                              reason: sampleEnabled ? nil : (starter.sampleReason ?? "Another document is opening."))
        }
    }

    /// The tile's first three presets as chips, each identified; a click creates that document.
    private func presets(_ tile: NewTile, busy: Bool) -> some View {
        let shown = Array(tile.presets.prefix(3))
        let options = shown.map { InspectorOption(id: $0.id, title: SuiteOnboarding.presetTitle($0), identifier: OnboardingControls.preset($0)) }
        return ChoiceChips(options: options, selected: nil) { picked in
            if let preset = shown.first(where: { $0.id == picked }) {
                Task { await model.startNew(preset, now: Date()) }
            }
        }
        .disabled(tile.disabledReason != nil || busy)
        .help(tile.disabledReason ?? "Creates a new \(tile.app.displayName) document at once.")
    }
}
