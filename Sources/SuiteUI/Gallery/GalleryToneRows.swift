// GalleryToneRows.swift: the gallery's `tone-rows` page (packet
// docs/blueprints/suiteui/features/tone-controls.md, TC-2, live in TC-8). It
// shows ToneRows on a GalleryToneBoard, the CLI's fake-tone document with its
// History, every slider at neutral to start. Each intent the rows send runs
// through ToneCommands in that document's catalog and writes one line,
// `<command id> [<step>, <n> in History] <intent>` (or `[refused: <why>]`), to
// `suite.gallery.log`, so a drag shows as one undo step. `applied` and `line`
// stay for the render budget's local rows. The page is its own area in
// `SuiteGallery.areas`. The rows scroll, the log stays under them.
import SuiteImaging
import SuiteKernel
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

/// The page's live target: a fake-tone document, whose catalog is ToneCommands' specs plus undo and redo.
struct GalleryToneBoard {
    private(set) var document = FakeToneDocument()
    var settings: ToneSettings { document.tone }

    /// Runs `intent`'s command; the log line: the step it made, or why it was refused, then the intent.
    mutating func send(_ intent: ToneIntent) -> String {
        let command = intent.command
        do {
            let outcome = try FakeToneDocument.catalog.run(command.id, params: command.params, on: &document)
            return "\(command.id) [\(outcome.undoStep ?? "no step"), \(document.history.steps.count) in History] \(intent)"
        } catch { return "\(command.id) [refused: \(error)] \(intent)" }
    }

    /// Takes back the last step; false when there is none.
    mutating func undo() -> Bool { document.step(redo: false) }
}

/// Internal, not private, so TC-4's snapshots and render budget can build it.
struct GalleryToneRowsPage: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    @State private var board = GalleryToneBoard()
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
                ToneRows(settings: board.settings, help: nil) { intent in
                    log.append(board.send(intent))
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
