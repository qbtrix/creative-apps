// SuiteHelpCommandsTests.swift (report-problem RP-2): the Help group, read as text since SwiftUI doesn't
// build on Linux. SuiteHelpCommands replaces the system's empty help item with the suite Help catalog's
// items, each built with MenuCommand(spec, on:) and identified: Report a Problem…, Beta Notes and, in the
// launcher only, Welcome to AfterGlow, which still opens the tour. Since RP-3 Report a Problem… begins the
// report sheet and Beta Notes opens its window, so no item is disabled; one that wasn't built would say why
// (no dead controls). The launcher adds the group in place of its Welcome group.
import Foundation
import Testing

@Suite struct SuiteHelpCommandsTests {
    static let help = "Sources/SuiteShell/SuiteHelpCommands.swift"

    @Test func groupReplacesTheSystemsHelpItem() throws {
        let text = try source(Self.help)
        #expect(text.contains("CommandGroup(replacing: .help)"))
        #expect(!text.contains("CommandGroup(after: .help)"))
        #expect(text.contains("public struct SuiteHelpCommands: Commands") && text.contains("public init(app: SuiteApp)"))
    }

    @Test func itemsAreTheCatalogsSpecsInMenuOrder() throws {
        let text = try source(Self.help)
        #expect(text.contains("SuiteHelpCatalog.catalog.spec(id)"))
        #expect(text.contains("MenuCommand(spec, on: document"), "an item isn't built from its spec")
        #expect(!text.contains("Button(") && !text.contains("MenuCommand(\""), "a bare menu item")
        let order = ["\"help.report-problem\"", "\"help.beta-notes\"", "\"help.welcome\""]
        let at = order.compactMap { text.range(of: $0)?.lowerBound }
        #expect(at.count == 3 && at == at.sorted(), "the ids aren't listed in menu order")
        #expect(text.contains("app == .launcher ? [\"help.welcome\"] : []"), "Welcome isn't the launcher's alone")
    }

    @Test func itemsCarryTheirIds() throws {
        let text = try source(Self.help)
        #expect(text.contains(".accessibilityIdentifier(Self.identifier(id))"))
        #expect(text.contains("id == \"help.welcome\" ? OnboardingControls.help : \"suite.\" + id"))
    }

    @Test func everyItemOpensItsWindow() throws {
        let text = try source(Self.help)
        #expect(text.contains("if id == \"help.welcome\" { openWindow(id: \"onboarding\") }"))
        #expect(text.contains("if id == \"help.report-problem\" { SuiteHelpPresenter.shared.showReport(app: app) }"))
        #expect(text.contains("if id == \"help.beta-notes\" { SuiteHelpPresenter.shared.showBetaNotes() }"))
        #expect(text.contains("static let notBuilt: [String: String] = [:]"), "an item is still disabled")
        #expect(text.contains("ProblemReportSheet(") && text.contains("beginSheet(panel)"), "the report isn't a sheet")
        #expect(text.contains("BetaNotesView(notes: BetaNotes.current)") && text.contains("window.title = \"Beta Notes\""))
        #expect(text.contains("isEnabled: false"))
    }

    @Test func providerAdaptsSuiteModel() throws {
        let text = try source("Sources/SuiteShell/ShellHelpProvider.swift")
        #expect(text.contains("public struct ShellHelpProvider: HelpProviding"))
        #expect(text.contains("ProblemReport.build(") && text.contains("BetaNotes.current"))
        #expect(!text.contains("URLSession") && !text.contains("NSWorkspace"), "the provider reaches the network")
    }

    /// RP-5b: the sheet's report holds this Mac's crashes, read from CrashFolder's folder and files only.
    @Test func providerReadsTheCrashFolder() throws {
        let provider = try source("Sources/SuiteShell/ShellHelpProvider.swift")
        #expect(provider.contains("crashes: CrashFolderReader.read("), "the report has no crashes")
        #expect(!provider.contains("crashes: [],"))
        let reader = try source("Sources/SuiteShell/CrashFolderReader.swift")
        #expect(reader.contains("CrashFolder.path(arguments: arguments, home: home)"))
        #expect(reader.contains("CrashFolder.toRead(entries, now: now)"), "the reader opens every file in the folder")
        #expect(!reader.contains("URLSession") && !reader.contains("NSWorkspace"), "the reader reaches the network")
        let journey = try source("UITests/AfterGlowJourneyTests+Help.swift")
        #expect(!journey.contains("XCTSkip"), "the Help journey is still skipped")
        #expect(journey.contains("\"-SuiteCrashDir\""))
    }

    @Test func launcherAddsTheGroupInPlaceOfItsWelcomeGroup() throws {
        let app = try source("Sources/AfterGlowApp/AfterGlowApp.swift")
        #expect(app.components(separatedBy: "SuiteHelpCommands(app: .launcher)").count == 2)
        #expect(!app.contains("LauncherCommandsOnboarding"))
        let root = try #require(packageRoot())
        let old = root.appendingPathComponent("Sources/AfterGlowApp/LauncherCommands+Onboarding.swift")
        #expect(!FileManager.default.fileExists(atPath: old.path), "the launcher keeps its own Welcome group")
    }

    /// The package root: the first folder above this file that holds Package.swift.
    private func packageRoot() -> URL? {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    /// The file's text without its comment lines.
    private func source(_ path: String) throws -> String {
        let root = try #require(packageRoot())
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        return text.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}
