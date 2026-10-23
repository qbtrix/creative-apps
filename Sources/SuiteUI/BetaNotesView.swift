// BetaNotesView.swift (report-problem RP-3): Help > Beta Notes's window. The build's known issues, each a title
// over its detail in a list at least two thirds of the content minimum tall (a window over the view
// opens at its minimum size), or a line saying there are none, then Close. It reads the list it is given
// (`BetaNotes.current` from the Help menu) and changes nothing.
import SwiftUI

/// The build's known issues, in the order given.
public struct BetaNotesView: View {
    nonisolated static let closeID = "suite.help.beta-notes.close"

    private let notes: [Note]
    private let onClose: @MainActor () -> Void

    public init(notes: [(title: String, detail: String)], onClose: @escaping @MainActor () -> Void) {
        self.notes = notes.enumerated().map { Note(id: $0.offset, title: $0.element.title, detail: $0.element.detail) }
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Beta Notes").font(SuiteFont.title)
            if notes.isEmpty {
                Text("No known issues in this build.").font(SuiteFont.body).foregroundStyle(SuiteColor.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: SuiteSpacing.m) {
                        ForEach(notes) { note in
                            VStack(alignment: .leading, spacing: SuiteSpacing.xxs) {
                                Text(note.title).font(SuiteFont.headline)
                                Text(note.detail).font(SuiteFont.body).foregroundStyle(SuiteColor.textSecondary)
                            }
                        }
                    }
                }
                // A window over this view opens at its minimum size, where a bare ScrollView has none.
                .frame(minHeight: SuiteSize.contentMinimum.height * 2 / 3)
            }
            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier(Self.closeID)
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentIdealWidth)
    }

    private struct Note: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }
}
