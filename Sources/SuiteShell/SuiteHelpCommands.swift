// SuiteHelpCommands.swift (report-problem RP-2): the suite's Help menu, built from SuiteHelpCatalog. It
// replaces the system's empty help item with Report a Problem…, Beta Notes and, in the launcher only,
// Welcome to AfterGlow, which opens the tour. Each item is MenuCommand(spec, on:) over a SuiteHelpDocument
// read through ShellHelpProvider. An item whose run isn't built yet is disabled and says why (no dead
// controls). Report a Problem… begins ProblemReportSheet on the front window over ShellHelpProvider's report
// (RP-3); Copy puts the text on the pasteboard, and Save… and Email… hand it to ProblemReportActions (RP-3e),
// so the app sends nothing itself. Beta Notes opens a window titled Beta Notes over BetaNotes.current,
// centred so it stays on a small screen. Connect an AI Assistant… (cli-bundle CB-5) begins AssistantConnectSheet
// on the front window over the running AfterGlow.app's AssistantConnectPanel; Copy puts its text on the pasteboard
// and Open AI Access opens Window > AI Access…'s list; Install Command-Line Tool… runs InstallCommandLineTool on the
// sheet (CB-6). The item is disabled, saying why, outside AfterGlow.app.
import AppKit
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI

public struct SuiteHelpCommands: Commands {
    private let app: SuiteApp
    @Environment(\.openWindow) private var openWindow

    public init(app: SuiteApp) { self.app = app }

    /// The catalog ids the Help menu shows for `app`, in menu order.
    static func ids(for app: SuiteApp) -> [String] {
        ["help.report-problem", "help.beta-notes", "help.connect-assistant"] + (app == .launcher ? ["help.welcome"] : [])
    }

    /// Why each item that runs nothing yet is disabled: none since RP-3.
    static let notBuilt: [String: String] = [:]

    /// The item's accessibility id: Welcome keeps the onboarding id its journeys use.
    static func identifier(_ id: String) -> String {
        id == "help.welcome" ? OnboardingControls.help : "suite." + id
    }

    private var document: SuiteHelpDocument { SuiteHelpDocument(app: app.rawValue, provider: ShellHelpProvider()) }

    public var body: some Commands {
        CommandGroup(replacing: .help) {
            ForEach(Self.ids(for: app), id: \.self) { id in
                if let spec = SuiteHelpCatalog.catalog.spec(id) {
                    MenuCommand(spec, on: document, notBuilt: Self.notBuilt[id]) { perform(id) }
                        .accessibilityIdentifier(Self.identifier(id))
                }
            }
        }
    }

    @MainActor private func perform(_ id: String) {
        if id == "help.welcome" { openWindow(id: "onboarding") }
        if id == "help.report-problem" { SuiteHelpPresenter.shared.showReport(app: app) }
        if id == "help.beta-notes" { SuiteHelpPresenter.shared.showBetaNotes() }
        if id == "help.connect-assistant", let bundle = ShellHelpProvider().bundle { SuiteHelpPresenter.shared.showConnect(bundle: bundle) }
    }
}

/// The process's Report a Problem sheet and Beta Notes window, one of each at a time.
@MainActor final class SuiteHelpPresenter {
    static let shared = SuiteHelpPresenter()

    private var host: NSWindow?
    private var sheet: NSWindow?
    private var notes: NSWindow?
    private(set) var connect: NSWindow?
    private var connectHost: NSWindow?
    private var report = ProblemReport(app: "", version: "", build: "", macOS: "", model: "", crashes: [])

    /// Begins the report sheet on the front window, or shows it as its own window when none is open.
    func showReport(app: SuiteApp) {
        if let sheet, sheet.sheetParent != nil || sheet.isVisible { sheet.makeKeyAndOrderFront(nil); return }
        // The report itself, not its JSON answer: only the report keeps the names that redact the note.
        report = ShellHelpProvider().problemReport(app: app.rawValue)
        let view = ProblemReportSheet(
            report: report,
            onCopy: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            onSave: { [weak self] text in self?.save(text) },
            onEmail: { [weak self] text in self?.email(text) },
            onClose: { [weak self] in self?.closeReport() })
        let panel = NSWindow(contentViewController: NSHostingController(rootView: view))
        panel.title = "Report a Problem"
        panel.isReleasedWhenClosed = false
        sheet = panel
        host = NSApp.keyWindow ?? NSApp.mainWindow
        if let host { host.beginSheet(panel) } else { panel.makeKeyAndOrderFront(nil) }
    }

    /// Save… and Email…: the sheet's text with this report's subject and file name.
    func save(_ text: String) { ProblemReportActions.save(ProblemReportOutput(report: report, text: text)) }
    func email(_ text: String) { ProblemReportActions.email(ProblemReportOutput(report: report, text: text)) }

    func closeReport() {
        guard let sheet else { return }
        if let host, sheet.sheetParent != nil { host.endSheet(sheet) } else { sheet.close() }
        self.sheet = nil
        host = nil
    }

    /// Begins the Connect an AI Assistant sheet for `bundle` on `window` (the front window when nil), or shows it as
    /// its own window when none is open.
    func showConnect(bundle: String, in window: NSWindow? = nil) {
        if let connect, connect.sheetParent != nil || connect.isVisible { connect.makeKeyAndOrderFront(nil); return }
        let view = AssistantConnectSheet(
            panel: AssistantConnectPanel(bundle: bundle),
            onCopy: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            onInstall: { [weak self] in
                let window = self?.connect
                Task { await InstallCommandLineTool.run(bundle: bundle, on: window) }
            },
            onOpenAIAccess: { AIAccessCenter.shared.showList() },
            onClose: { [weak self] in self?.closeConnect() })
        let panel = NSWindow(contentViewController: NSHostingController(rootView: view))
        panel.title = "Connect an AI Assistant"
        panel.isReleasedWhenClosed = false
        connect = panel
        connectHost = window ?? NSApp.keyWindow ?? NSApp.mainWindow
        if let connectHost { connectHost.beginSheet(panel) } else { panel.makeKeyAndOrderFront(nil) }
    }

    func closeConnect() {
        guard let connect else { return }
        if let connectHost, connect.sheetParent != nil { connectHost.endSheet(connect) } else { connect.close() }
        self.connect = nil
        connectHost = nil
    }

    /// Opens, or brings forward, the Beta Notes window.
    func showBetaNotes() {
        if notes == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: BetaNotesView(notes: BetaNotes.current) { [weak self] in
                self?.notes?.close()
            }))
            window.title = "Beta Notes"
            window.isReleasedWhenClosed = false
            window.center()
            notes = window
        }
        notes?.makeKeyAndOrderFront(nil)
    }
}

extension MenuCommand {
    /// The catalog item, or, when `notBuilt` gives a reason, the spec's title disabled with "<title>: <reason>".
    init<T>(_ spec: CommandSpec<T>, on target: T, notBuilt: String?, perform: @escaping @MainActor () -> Void) {
        if let notBuilt {
            self.init(spec.title, help: "\(spec.title): \(notBuilt)", isEnabled: false, perform: perform)
        } else {
            self.init(spec, on: target, perform: perform)
        }
    }
}
