// SuiteHelpCommands.swift (report-problem RP-2): the suite's Help menu, built from SuiteHelpCatalog. It
// replaces the system's empty help item with Report a Problem…, Beta Notes and, in the launcher only,
// Welcome to AfterGlow, which opens the tour. Each item is MenuCommand(spec, on:) over a SuiteHelpDocument
// read through ShellHelpProvider. An item whose run isn't built yet is disabled and says why (no dead
// controls). Report a Problem… begins ProblemReportSheet on the front window over ShellHelpProvider's report
// (RP-3); Copy puts the text on the pasteboard and the app sends nothing itself. Beta Notes opens a window
// titled Beta Notes over BetaNotes.current.
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
        ["help.report-problem", "help.beta-notes"] + (app == .launcher ? ["help.welcome"] : [])
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
    }
}

/// The process's Report a Problem sheet and Beta Notes window, one of each at a time.
@MainActor final class SuiteHelpPresenter {
    static let shared = SuiteHelpPresenter()

    private var host: NSWindow?
    private var sheet: NSWindow?
    private var notes: NSWindow?

    /// Begins the report sheet on the front window, or shows it as its own window when none is open.
    func showReport(app: SuiteApp) {
        if let sheet, sheet.sheetParent != nil || sheet.isVisible { sheet.makeKeyAndOrderFront(nil); return }
        let view = ProblemReportSheet(
            report: Self.report(ShellHelpProvider().report(app: app.rawValue, note: "")),
            onCopy: { text in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            },
            onClose: { [weak self] in self?.closeReport() })
        let panel = NSWindow(contentViewController: NSHostingController(rootView: view))
        panel.title = "Report a Problem"
        panel.isReleasedWhenClosed = false
        sheet = panel
        host = NSApp.keyWindow ?? NSApp.mainWindow
        if let host { host.beginSheet(panel) } else { panel.makeKeyAndOrderFront(nil) }
    }

    func closeReport() {
        guard let sheet else { return }
        if let host, sheet.sheetParent != nil { host.endSheet(sheet) } else { sheet.close() }
        self.sheet = nil
        host = nil
    }

    /// Opens, or brings forward, the Beta Notes window.
    func showBetaNotes() {
        if notes == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: BetaNotesView(notes: BetaNotes.current) { [weak self] in
                self?.notes?.close()
            }))
            window.title = "Beta Notes"
            window.isReleasedWhenClosed = false
            notes = window
        }
        notes?.makeKeyAndOrderFront(nil)
    }

    /// ShellHelpProvider's report object back as a ProblemReport; "" for a field it lacks.
    static func report(_ value: JSONValue) -> ProblemReport {
        guard case .object(let fields) = value else {
            return ProblemReport(app: "", version: "", build: "", macOS: "", model: "", crashes: [])
        }
        func string(_ value: JSONValue?) -> String? {
            if case .string(let text)? = value { return text }
            return nil
        }
        var crashes: [String] = []
        if case .array(let list)? = fields["crashes"] { crashes = list.compactMap(string) }
        return ProblemReport(
            app: string(fields["app"]) ?? "", version: string(fields["version"]) ?? "", build: string(fields["build"]) ?? "",
            macOS: string(fields["macOS"]) ?? "", model: string(fields["model"]) ?? "", crashes: crashes)
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
