// OnboardingStartPage.swift: the welcome window's page 3, the starter row
// (onboarding packet OB-4). One grid row per starter in the model's focus
// order: the app's mark and name, its presets as ChoiceChips (SuiteOnboarding.presetTitle:
// "New Blank Design", or the preset's own "Import Folder…" when it asks for more) and
// "Open sample". A disabled control's help is the model's reason (#3018).
// While a hand-off is in flight its row shows a small progress ring and every
// control is disabled; a refused hand-off's sentence sits in its own grid
// row under that row's chips, so the row itself never moves, and is never an
// alert. "Start from an empty home" is the window's default button
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
                    // Its own row under the chips, so a refusal never moves the row above it.
                    if model.failed == starter.tile.app, let message = model.message {
                        GridRow {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            Text(message.message).font(SuiteFont.caption).foregroundStyle(SuiteColor.stateWarning)
                                .fixedSize(horizontal: false, vertical: true)
                                .gridCellColumns(2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.failed == nil, let message = model.message {
                Text(message.message).font(SuiteFont.caption).foregroundStyle(SuiteColor.stateWarning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// One starter: the app's mark and name, its preset chips, Open sample.
    private func row(_ starter: OnboardingStarter) -> some View {
        let app = starter.tile.app
        let busy = model.launching != nil
        let sampleReason = model.sampleUnavailable(starter)
        return GridRow(alignment: .center) {
            HStack(spacing: SuiteSpacing.s) {
                AppMark(app: app, style: .line).symbolSized().font(SuiteFont.body)
                Text(app.displayName).font(SuiteFont.body).foregroundStyle(SuiteColor.textPrimary)
                if model.launching == app {
                    ProgressView().controlSize(.small).accessibilityLabel("Opening \(app.displayName)")
                }
            }
            .accessibilityElement(children: .combine)
            presets(starter.tile, busy: busy)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Open sample") { Task { await model.openSample(app, now: Date()) } }
                .disabled(sampleReason != nil)
                .help(model.sampleHelp(starter))
                .suiteControl(id: OnboardingControls.sample(app), enabled: sampleReason == nil, reason: sampleReason)
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
        .help(model.presetsHelp(tile))
    }
}
