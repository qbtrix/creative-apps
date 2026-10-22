// SuiteHelpSnapshots.swift (report-problem RP-3): suite-help-report (the Report a Problem sheet with a note)
// and suite-help-beta-notes (the Beta Notes window with two notes), each -light and -dark.
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteHelpSnapshots {
    private let report = ProblemReport(
        app: "Photo", version: "1.0", build: "42", macOS: "Version 27.0 (Build 27A100)", model: "Mac15,3", crashes: [])
    private let notes = [
        (title: "Export can stall on very large documents", detail: "Saving a copy of a document over 2 GB may pause the app for a few seconds."),
        (title: "Brush previews lag on external displays", detail: "Moving a window to a second display can delay the brush cursor until the next stroke."),
    ]

    @Test func reportSheetAndBetaNotes() throws {
        for (scheme, suffix) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            let sheet = ProblemReportSheet(report: report, note: "The canvas went blank after I undid a crop.", onCopy: { _ in }, onClose: {})
            try snapshot(staged(sheet), name: "suite-help-report-\(suffix)", scheme: scheme)
            try snapshot(staged(BetaNotesView(notes: notes) {}), name: "suite-help-beta-notes-\(suffix)", scheme: scheme)
        }
    }

    /// `view` on a panel at the top left of the 1440x900 frame.
    private func staged(_ view: some View) -> some View {
        view.background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
