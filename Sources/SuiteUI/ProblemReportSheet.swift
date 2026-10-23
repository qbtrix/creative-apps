// ProblemReportSheet.swift (report-problem RP-3): Help > Report a Problem…'s sheet. A note field on top, the
// report read-only below it, then Copy, Save…, Email… and Close. The sheet sends nothing itself: each action
// hands the note plus the report (`ProblemReport.text(note:)`) to its host, and Save… and Email… stay disabled,
// saying why, until the host passes them (RP-3e). The note lives in its own field view and a plain box the
// sheet doesn't watch, so a keystroke runs no sheet body (RenderBudgetHelpTests). Every control carries
// `suite.help.report.<control>`.
import SuiteModel
import SwiftUI

/// The Report a Problem sheet over `report`.
public struct ProblemReportSheet: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif
    /// The controls, each with its `identifier(_:)`.
    nonisolated static let controls = ["note", "report", "copy", "save", "email", "close"]
    nonisolated static func identifier(_ control: String) -> String { "suite.help.report." + control }

    private let report: ProblemReport
    private let onCopy: @MainActor (String) -> Void
    private let onSave: (@MainActor (String) -> Void)?
    private let onEmail: (@MainActor (String) -> Void)?
    private let onClose: @MainActor () -> Void
    @State private var draft: NoteDraft

    /// `note` seeds the field; a nil `onSave` or `onEmail` shows that button disabled.
    public init(
        report: ProblemReport, note: String = "", onCopy: @escaping @MainActor (String) -> Void,
        onSave: (@MainActor (String) -> Void)? = nil, onEmail: (@MainActor (String) -> Void)? = nil,
        onClose: @escaping @MainActor () -> Void
    ) {
        self.report = report
        (self.onCopy, self.onSave, self.onEmail, self.onClose) = (onCopy, onSave, onEmail, onClose)
        _draft = State(initialValue: NoteDraft(text: note))
    }

    public var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                Text("Report a Problem").font(SuiteFont.title)
                Text("Say what happened. Nothing leaves this Mac until you send it.")
                    .font(SuiteFont.body).foregroundStyle(SuiteColor.textSecondary)
            }
            ProblemReportNote(draft: draft).accessibilityIdentifier(Self.identifier("note"))
            ScrollView {
                Text(shown).font(SuiteFont.timecode).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(SuiteSpacing.s)
            }
            .frame(height: SuiteSize.contentMinimum.height / 2)
            .background(SuiteColor.card, in: RoundedRectangle(cornerRadius: SuiteRadius.control))
            .accessibilityIdentifier(Self.identifier("report"))
            HStack(spacing: SuiteSpacing.s) {
                Button("Close", role: .cancel) { onClose() }
                    .keyboardShortcut(.cancelAction).accessibilityIdentifier(Self.identifier("close"))
                Spacer()
                action("Save…", onSave, why: "Saving the report isn't in this build yet.", id: "save")
                action("Email…", onEmail, why: "Emailing the report isn't in this build yet.", id: "email")
                Button("Copy") { onCopy(report.text(note: draft.text)) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier(Self.identifier("copy"))
            }
        }
        .padding(SuiteSpacing.xl)
        .frame(width: SuiteSize.contentIdealWidth)
    }

    /// The report as it will be sent, after the note; its summary line while the report has no body yet.
    private var shown: String {
        let text = report.text(note: "")
        return text.isEmpty ? "\(report.app) \(report.version) (\(report.build)) · \(report.macOS) · \(report.model)" : text
    }

    /// A button that hands the note plus the report to `run`, or, with no `run`, disabled saying `why`.
    private func action(_ title: String, _ run: (@MainActor (String) -> Void)?, why: String, id: String) -> some View {
        Button(title) { run?(report.text(note: draft.text)) }
            .disabled(run == nil).help(run == nil ? why : title)
            .accessibilityIdentifier(Self.identifier(id))
    }
}

/// The note as typed: a box the sheet reads on an action and never watches, so typing runs no sheet body.
@MainActor final class NoteDraft {
    var text: String
    init(text: String) { self.text = text }
}

/// The note field: its own state, copied into the draft on every change.
private struct ProblemReportNote: View {
    let draft: NoteDraft
    @State private var text: String

    init(draft: NoteDraft) {
        self.draft = draft
        _text = State(initialValue: draft.text)
    }

    var body: some View {
        TextField("What were you doing when it went wrong?", text: Binding(get: { text }, set: { text = $0; draft.text = $0 }), axis: .vertical)
            .lineLimit(3...6).textFieldStyle(.roundedBorder).font(SuiteFont.body)
    }
}
