// FlareImportNote.swift: the note above the stage after a Lottie open (feature lottie-open LO-4,
// docs/blueprints/flare/features/lottie-open.md), an adapter onto SuiteUI's InspectorNote. One InspectorNote row per part the reader left out, in export's
// ExportScan row shape (rule 20; FlareExportOptionRows' warnings), or "Nothing was skipped." for none, beside a
// system Dismiss button. It only reads `rows` (`model.importNoteRows`); Dismiss calls `onDismiss`, the window's
// `model.dismissImportNote()`. With no rows it draws nothing. Journeys read `flare.import.note` and press
// `flare.import.dismiss`.
import SuiteUI
import SwiftUI

struct FlareImportNoteAdapter: View {
    static let identifier = "flare.import.note"
    static let dismissIdentifier = "flare.import.dismiss"
    let rows: [String]
    let onDismiss: @MainActor () -> Void

    var body: some View {
        if !rows.isEmpty {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: SuiteSpacing.s) {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { InspectorNote($0.element) }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(Self.identifier)
                    Button("Dismiss") { onDismiss() }
                        .accessibilityIdentifier(Self.dismissIdentifier)
                }
                .padding(.vertical, SuiteSpacing.xs)
                .padding(.trailing, SuiteSpacing.m)
                Divider()
            }
        }
    }
}
