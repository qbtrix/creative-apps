// SuiteHelpSnapshots.swift (report-problem RP-3): suite-help-report (the Report a Problem sheet with a note)
// and suite-help-beta-notes (the Beta Notes window with two notes), each -light and -dark. The Beta Notes
// window is sized to its view's fitting size, so the notes must take room there, not only on a full frame.
#if canImport(AppKit)
import AppKit
#endif
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

    /// cli-bundle CB-5b: suite-help-connect, the Connect an AI Assistant sheet for an installed bundle: the bundled
    /// command and config with their Copy buttons, and Install Command-Line Tool… enabled (CB-6).
    @Test func connectSheet() throws {
        let panel = AssistantConnectPanel(bundle: "/Applications/AfterGlow.app")
        for (scheme, suffix) in [(ColorScheme.light, "light"), (.dark, "dark")] {
            let sheet = AssistantConnectSheet(panel: panel, onCopy: { _ in }, onInstall: {}, onOpenAIAccess: {}, onClose: {})
            try snapshot(staged(sheet), name: "suite-help-connect-\(suffix)", scheme: scheme)
        }
    }

    #if canImport(AppKit)
    /// Help > Beta Notes's window opens at its view's minimum size: with notes it is taller than with none, so the
    /// notes list doesn't collapse to nothing between the title and Close.
    @Test func betaNotesWindowFitsItsNotes() {
        let notes = BetaNotes.current
        func height(_ notes: [(title: String, detail: String)]) -> CGFloat {
            // The height the view takes when offered none: what a window over it opens at.
            NSHostingController(rootView: BetaNotesView(notes: notes) {}).sizeThatFits(in: .zero).height
        }
        #expect(height(notes) > height([]) + 100, "the notes list collapses in the fitted window")
    }
    #endif

    /// `view` on a panel at the top left of the 1440x900 frame.
    private func staged(_ view: some View) -> some View {
        view.background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
