// ProblemReportOutput.swift (report-problem RP-3e): what Help > Report a Problem…'s Save… and Email… hand on.
// The mail's subject "AfterGlow <app> <version> problem", its recipients (the beta address, of which the build
// names none yet, so the person picks), and the text, which is exactly the sheet's note plus report; the saved
// file's name is the subject as a .txt. SuiteShell's ProblemReportActions passes these to AppKit; nothing here
// or there opens a socket. Linux-safe.

/// The subject, recipients, file name and text of one report on its way out.
public struct ProblemReportOutput: Hashable, Sendable {
    /// The beta address the mail goes to. Empty: the build names none, so the person's mail app asks.
    public static let betaAddresses: [String] = []

    public let subject: String
    public let recipients: [String]
    public let fileName: String
    /// The mail body and the saved file: the sheet's text, unchanged.
    public let text: String

    public init(report: ProblemReport, text: String) {
        let app = report.app == SuiteApp.launcher.displayName ? "" : report.app
        subject = (["AfterGlow", app, report.version, "problem"].filter { !$0.isEmpty }).joined(separator: " ")
        recipients = Self.betaAddresses
        fileName = String(subject.map { $0 == "/" || $0 == ":" ? "-" : $0 }) + ".txt"
        self.text = text
    }
}
