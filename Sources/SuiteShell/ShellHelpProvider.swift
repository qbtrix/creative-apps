// ShellHelpProvider.swift (report-problem RP-2): SuiteModel's ProblemReport and BetaNotes adapted to the
// kernel's HelpProviding, so the Help catalog's commands read this Mac's app, version, build, macOS and model,
// and its recent crash files through CrashFolderReader (RP-5b). It answers through SuiteHelpCatalog's
// reportAnswer and notesAnswer, as the CLI's HelpReports does, so the sheet and the CLI never differ. Reads no network: the host name it redacts
// comes from gethostname, never ProcessInfo.hostName, which raises the local network prompt.
import Foundation
import SuiteKernel
import SuiteModel

public struct ShellHelpProvider: HelpProviding {
    public init() {}

    public func report(app: String, note: String) -> JSONValue {
        let info = Bundle.main.infoDictionary ?? [:]
        let process = ProcessInfo.processInfo
        let report = ProblemReport.build(
            app: SuiteApp(rawValue: app) ?? .launcher,
            version: info["CFBundleShortVersionString"] as? String ?? "",
            build: info["CFBundleVersion"] as? String ?? "",
            macOS: process.operatingSystemVersionString, model: Self.model(),
            crashes: CrashFolderReader.read(), now: Date(), home: NSHomeDirectory(), user: NSUserName(), host: Self.host())
        return SuiteHelpCatalog.reportAnswer(report, text: report.text(note: note))
    }

    /// The AfterGlow.app this process runs in, a helper app's included; nil outside one (cli-bundle CB-5).
    public var bundle: String? { AssistantConnectPanel.bundle(containing: Bundle.main.bundlePath) }

    /// `{command, json}` for the running bundle, AssistantConnect's text as the sheet shows it; null outside one.
    public func connectAssistant() -> JSONValue {
        guard let bundle else { return .null }
        let panel = AssistantConnectPanel(bundle: bundle)
        return .object(["command": .string(panel.command), "json": .string(panel.configJSON)])
    }

    public func betaNotes() -> JSONValue { SuiteHelpCatalog.notesAnswer(BetaNotes.current) }

    /// This Mac's host name from the kernel. ProcessInfo.hostName resolves it over the network, which raises
    /// macOS's local network prompt; gethostname reads no network.
    static func host() -> String {
        var bytes = [CChar](repeating: 0, count: 256)
        guard gethostname(&bytes, bytes.count) == 0 else { return "" }
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The Mac's model identifier ("Mac15,3"), or "" when sysctl can't read it.
    static func model() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &bytes, &size, nil, 0) == 0 else { return "" }
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
