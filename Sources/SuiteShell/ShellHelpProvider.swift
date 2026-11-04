// ShellHelpProvider.swift (report-problem RP-2): SuiteModel's ProblemReport and BetaNotes adapted to the
// kernel's HelpProviding, so the Help catalog's commands read this Mac's app, version, build, macOS and model,
// and its recent crash files, through SuiteModel's ThisMac and CrashFolderReader, which the CLI's HelpReports reads
// too. It answers through SuiteHelpCatalog's reportAnswer and notesAnswer, so the sheet and the CLI never differ;
// the sheet takes `problemReport(app:)` itself, which keeps the names to redact from its note. Reads no network.
import Foundation
import SuiteKernel
import SuiteModel

public struct ShellHelpProvider: HelpProviding {
    public init() {}

    public func report(app: String, note: String) -> JSONValue {
        let report = problemReport(app: app)
        return SuiteHelpCatalog.reportAnswer(report, text: report.text(note: note))
    }

    /// The report itself, which keeps the names it redacts, so the sheet redacts its note too. The JSON answer
    /// never carries them, so a report decoded from it can't.
    public func problemReport(app: String) -> ProblemReport {
        ProblemReport.build(
            app: SuiteApp(rawValue: app) ?? .launcher, version: ThisMac.version, build: ThisMac.build,
            macOS: ThisMac.macOS, model: ThisMac.model,
            crashes: CrashFolderReader.read(arguments: ProcessInfo.processInfo.arguments, home: ThisMac.home, now: Date()),
            now: Date(), home: ThisMac.home, user: ThisMac.user, host: ThisMac.host)
    }

    /// The AfterGlow.app this process runs in, a helper app's included; nil outside one (cli-bundle CB-5).
    public var bundle: String? { AssistantConnectPanel.bundle(containing: Bundle.main.bundlePath) }

    /// `{command, json}` for the running bundle, AssistantConnect's text as the sheet shows it; null outside one.
    public func connectAssistant() -> JSONValue {
        guard let bundle else { return .null }
        let panel = AssistantConnectPanel(bundle: bundle)
        return .object(["command": .string(panel.command), "json": .string(panel.configJSON)])
    }

    /// The `~/.local/bin/afterglow` plan for the running bundle, the link made with `confirm`; null outside one. The
    /// home is `-SuiteHomeDir`'s in a journey. CommandLineInstall.run decides it, as for the CLI (cli-bundle CB-z).
    public func installCLI(confirm: Bool) -> JSONValue {
        guard let bundle else { return .null }
        let home = CommandLineInstall.home(arguments: ProcessInfo.processInfo.arguments, fallback: NSHomeDirectory())
        let result = CommandLineInstall.run(home: home, bundle: bundle, confirm: confirm, existing: CommandLineInstall.linkTarget)
        return SuiteHelpCatalog.planAnswer(plan: result.plan, at: result.at, to: result.to, reason: result.reason,
                                           linked: result.linked)
    }

    public func betaNotes() -> JSONValue { SuiteHelpCatalog.notesAnswer(BetaNotes.current) }
}
