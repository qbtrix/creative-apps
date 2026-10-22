// ProblemReportActions.swift (report-problem RP-3e): the AppKit glue behind the Report a Problem sheet's
// Save… and Email…. Email… hands the sheet's text to the system's compose-mail service with
// ProblemReportOutput's subject and recipients, so the person's own mail app opens it unsent; Save… writes the
// same text as a .txt where the person picks in a save panel. Neither opens a socket: nothing leaves the Mac
// unless the person sends it.
import AppKit
import SuiteModel
import UniformTypeIdentifiers

@MainActor enum ProblemReportActions {
    /// Opens a new mail in the person's mail app with the report's subject and text, or says why it can't.
    static func email(_ output: ProblemReportOutput) {
        guard let service = NSSharingService(named: .composeEmail), service.canPerform(withItems: [output.text]) else {
            return explain("Can't start an email", "Set up an account in Mail, or use Save… or Copy and send the report yourself.")
        }
        service.subject = output.subject
        service.recipients = output.recipients
        service.perform(withItems: [output.text])
    }

    /// Asks where to save the report, then writes the sheet's text there as plain text.
    static func save(_ output: ProblemReportOutput) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = output.fileName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Data(output.text.utf8).write(to: url, options: .atomic)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static func explain(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}
