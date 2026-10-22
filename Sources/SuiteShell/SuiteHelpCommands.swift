// SuiteHelpCommands.swift (report-problem RP-2): the suite's Help menu, built from SuiteHelpCatalog. It
// replaces the system's empty help item with Report a Problem…, Beta Notes and, in the launcher only,
// Welcome to AfterGlow, which opens the tour. Each item is MenuCommand(spec, on:) over a SuiteHelpDocument
// read through ShellHelpProvider. An item whose run isn't built yet is disabled and says why (no dead
// controls); RP-5 wires the report sheet and the beta notes window and drops it from `notBuilt`.
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

    /// Why each item that runs nothing yet is disabled.
    static let notBuilt = [
        "help.report-problem": "The report sheet isn't in this build yet.",
        "help.beta-notes": "The beta notes window isn't in this build yet.",
    ]

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
