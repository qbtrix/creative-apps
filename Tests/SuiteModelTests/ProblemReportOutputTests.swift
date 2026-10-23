// ProblemReportOutputTests.swift (report-problem RP-3e): what Save… and Email… hand on. The mail's subject is
// "AfterGlow <app> <version> problem", it has no recipients beyond the beta address (the build names none, so
// the person picks), and its body, like the saved file, is exactly the sheet's text. The file name is the
// subject as a safe .txt name. Linux-safe.
import SuiteModel
import Testing

@Suite struct ProblemReportOutputTests {
    static func report(_ app: SuiteApp = .photo, version: String = "0.9.0") -> ProblemReport {
        ProblemReport.build(app: app, version: version, build: "412", macOS: "26.1", model: "Mac16,1",
                            crashes: [], now: .init(timeIntervalSince1970: 0), home: "/Users/t", user: "t", host: "h")
    }

    static let sheetText = "It froze when I zoomed.\n\nPhoto 0.9.0 (412)\nmacOS 26.1 · Mac16,1\n"

    @Test func subjectNamesTheAppAndVersion() {
        #expect(ProblemReportOutput(report: Self.report(), text: Self.sheetText).subject == "AfterGlow Photo 0.9.0 problem")
        #expect(ProblemReportOutput(report: Self.report(.halo, version: "1.2"), text: "").subject == "AfterGlow Halo 1.2 problem")
    }

    @Test func launcherSubjectSaysAfterGlowOnce() {
        #expect(ProblemReportOutput(report: Self.report(.launcher), text: "").subject == "AfterGlow 0.9.0 problem")
    }

    @Test func missingVersionLeavesNoGap() {
        #expect(ProblemReportOutput(report: Self.report(version: ""), text: "").subject == "AfterGlow Photo problem")
    }

    @Test func mailHasNoRecipientsBeyondTheBetaAddress() {
        let output = ProblemReportOutput(report: Self.report(), text: Self.sheetText)
        #expect(output.recipients == ProblemReportOutput.betaAddresses)
        #expect(output.recipients.isEmpty, "the build names no beta address, so the person picks the recipient")
    }

    @Test func mailBodyAndSavedFileAreTheSheetsText() {
        let output = ProblemReportOutput(report: Self.report(), text: Self.sheetText)
        #expect(output.text == Self.sheetText)
        #expect(Array(output.text.utf8) == Array(Self.sheetText.utf8), "the saved bytes differ from the sheet")
    }

    @Test func fileNameIsTheSubjectAsText() {
        #expect(ProblemReportOutput(report: Self.report(), text: "").fileName == "AfterGlow Photo 0.9.0 problem.txt")
    }

    @Test func fileNameDropsPathSeparators() {
        let name = ProblemReportOutput(report: Self.report(version: "1.0/beta:2"), text: "").fileName
        #expect(name == "AfterGlow Photo 1.0-beta-2 problem.txt")
        #expect(!name.contains("/") && !name.contains(":"))
    }
}
