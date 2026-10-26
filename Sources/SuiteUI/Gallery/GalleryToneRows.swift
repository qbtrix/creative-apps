// GalleryToneRows.swift: the gallery's `tone-rows` page (packet
// docs/blueprints/suiteui/features/tone-controls.md, TC-2). It shows ToneRows
// on a local ToneSettings value, every slider at neutral to start. Each intent
// the rows send writes one line, `<command id> <intent>`, to `suite.gallery.log`
// and applies to the local value (a set or a reset; Auto only logs), so the
// rows follow with no History yet. TC-8 runs the intents through ToneCommands
// on a local target with a History instead. The page is its own area in
// `SuiteGallery.areas`. The rows scroll, the log stays under them.
import SuiteImaging
import SwiftUI

enum GalleryToneRows {
    static let name = "tone-rows"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryToneRowsPage()) }]

    /// The local value after `intent`: a set or a reset applied, Auto left as it is.
    static func applied(_ intent: ToneIntent, to settings: ToneSettings) -> ToneSettings {
        switch intent {
        case .set(let slider, let value, _): settings.setting(slider, to: value)
        case .reset(let group): settings.reset(group)
        case .auto: settings
        }
    }

    /// The log line: "tone.set set(temperature, 30.0, drag: Optional("d1"))".
    static func line(_ intent: ToneIntent) -> String {
        "\(intent.command.id) \(intent)"
    }
}

/// Internal, not private, so TC-4's snapshots and render budget can build it.
struct GalleryToneRowsPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var settings = ToneSettings.neutral
    @State private var log: [String] = []

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        let text = log.joined(separator: "\n")
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Tone rows").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText).accessibilityAddTraits(.isHeader)
            // Scrolls: the four sections run past a 768-pt runner's window (#5324).
            ScrollView {
                ToneRows(settings: settings, help: nil) { intent in
                    settings = GalleryToneRows.applied(intent, to: settings)
                    log.append(GalleryToneRows.line(intent))
                    if log.count > 40 { log.removeFirst(log.count - 40) }
                }
                .frame(width: SuiteSize.editorPanelWidth, alignment: .leading)
            }
            // No scroller: a legacy scroller's page area is an unnamed button
            // with no identifier to the app audit, as in GalleryGradientEditor.
            .scrollIndicators(.never)
            .frame(width: SuiteSize.editorPanelWidth)
            .accessibilityIdentifier("suite.gallery.tone-rows.scroll")
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText).lineLimit(1)
                .accessibilityLabel(text).accessibilityValue(text)
                .accessibilityIdentifier("suite.gallery.log")
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
