// SuiteHelpCatalog.swift (report-problem RP-1 specs, RP-5 bodies): the suite's Help commands, which the Help group
// builds its items from and `afterglow run suite <id>` runs. Foundation only: the kernel can't link SuiteModel, so
// the report and the notes come through `HelpProviding`, which SuiteShell and the CLI adapt.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Where the Help commands read the report and the beta notes: SuiteModel's `ProblemReport` and `BetaNotes`, adapted.
public protocol HelpProviding: Sendable {
    /// The report for `app` with the person's `note` on top.
    func report(app: String, note: String) -> JSONValue
    /// The build's known issues: `{"notes": [{"title", "detail"}]}`.
    func betaNotes() -> JSONValue
    /// The AfterGlow.app the assistant commands name (cli-bundle CB-2): the running bundle or the CLI's `--bundle`;
    /// nil outside a bundle.
    var bundle: String? { get }
    /// `{command, json}` for `bundle`: SuiteModel's `AssistantConnect` text.
    func connectAssistant() -> JSONValue
    /// The plan for the `~/.local/bin/afterglow` link to `bundle`'s CLI; with `confirm`, the link made too.
    func installCLI(confirm: Bool) -> JSONValue
}

/// A provider that knows no bundle, as one built before cli-bundle: the assistant commands are unavailable.
extension HelpProviding {
    public var bundle: String? { nil }
    public func connectAssistant() -> JSONValue { .null }
    public func installCLI(confirm: Bool) -> JSONValue { .null }
}

/// The Help commands' target: the app whose Help menu runs them, the provider they read and the last answer.
/// Its file (`.suitehelp`) holds what the provider needs, so only a provider opens one: the CLI's `HelpReports`.
public struct SuiteHelpDocument: HeadlessDocument {
    /// The app ("launcher", "photo") and the provider.
    public let app: String, provider: any HelpProviding
    /// The last report or notes a run answered with; null before the first.
    public fileprivate(set) var answer: JSONValue = .null
    public init(app: String, provider: any HelpProviding) { (self.app, self.provider) = (app, provider) }

    public static let app = "suite"
    public static let openExtensions = ["suitehelp"], exportFormats: [String] = []
    public static var catalog: CommandCatalog<SuiteHelpDocument> { SuiteHelpCatalog.catalog }
    static let needsProvider = "A .suitehelp file opens through a Help provider, as the afterglow CLI's suite app does."
    public static func open(_ data: Data, name: String) throws -> Self { throw CatalogError.unavailable(id: "open", why: needsProvider) }
    public static func new(_ options: JSONValue) throws -> Self { throw CatalogError.unavailable(id: "new", why: needsProvider) }
    /// The app and the last answer, as one JSON object with sorted keys.
    public func save() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(JSONValue.object(["app": .string(app), "answer": answer]))
    }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    public func summary() -> JSONValue { .object(["app": .string(app)]) }
}

/// The suite's Help catalog: `help.report-problem`, `help.beta-notes`, `help.welcome`, and cli-bundle's
/// `help.connect-assistant` and `help.install-cli` (CB-2 specs; CB-4 fills the provider's answers).
public enum SuiteHelpCatalog {
    /// `help.report-problem`'s params: the app to report on (the document's when left out) and the person's note.
    public struct ReportParams: Codable, Sendable { public var app: String?; public var note: String? }
    /// No params.
    public struct NoParams: Codable, Sendable {}
    /// `help.install-cli`'s params: whether to make the link; the plan only when left out or false.
    public struct InstallParams: Codable, Sendable { public var confirm: Bool? }

    /// The apps a report can name.
    static let apps = ["launcher", "flare", "design", "photo", "library", "halo"]
    /// The report's params, closed.
    static let reportParams = ParamSchema.object(
        ["app": .optional(.string("The app to report on; the running app when left out.", oneOf: apps)),
         "note": .optional(.string("The person's note, put on top of the report.", maxLength: 10_000))], required: ["app", "note"])
    /// The report: its fields, its crashes and its plain text.
    static let reportResult = ParamSchema.object(
        ["app": .string(), "version": .string(), "build": .string(), "macOS": .string(), "model": .string(),
         "crashes": .array(of: .string(), maxItems: 3), "text": .string()],
        required: ["app", "version", "build", "macOS", "model", "crashes", "text"])
    /// The known issues.
    static let notesResult = ParamSchema.object(
        ["notes": .array(of: .object(["title": .string(), "detail": .string()], required: ["title", "detail"]))], required: ["notes"])

    /// The bundled server's command line and the client config block.
    static let connectResult = ParamSchema.object(["command": .string(), "json": .string()], required: ["command", "json"])
    /// The install's params, closed.
    static let installParams = ParamSchema.object(
        ["confirm": .optional(ParamSchema.boolean)], required: ["confirm"])
    /// The install plan (`link`, `alreadyLinked` or `refuse`), its paths or reason, and whether the link is in place.
    static let planResult = ParamSchema.object(
        ["plan": .string(oneOf: ["link", "alreadyLinked", "refuse"]), "at": .optional(.string()), "to": .optional(.string()),
         "reason": .optional(.string()), "linked": .boolean], required: ["plan", "at", "to", "reason", "linked"])
    /// A `planResult` value, a nil field left out: the one mapping the CLI's and the app's providers both answer with
    /// (SuiteModel's CommandLineInstall.run decides the fields).
    public static func planAnswer(plan: String, at: String?, to: String?, reason: String?, linked: Bool) -> JSONValue {
        var fields: [String: JSONValue] = ["plan": .string(plan), "linked": .bool(linked)]
        for (key, value) in [("at", at), ("to", to), ("reason", reason)] { if let value { fields[key] = .string(value) } }
        return .object(fields)
    }
    /// Why the assistant commands can't run: no AfterGlow.app to name.
    static let needsBundle = "Connecting an assistant needs AfterGlow.app: run the bundled afterglow, or pass --bundle <path to AfterGlow.app>."
    static func bundled(_ doc: SuiteHelpDocument) -> Availability { doc.provider.bundle == nil ? .unavailable(needsBundle) : .available }

    /// A report's answer, the one shape every provider gives: its encoded fields plus `text`; null when it
    /// doesn't encode to an object.
    public static func reportAnswer(_ report: some Encodable, text: String) -> JSONValue {
        guard case .object(var fields)? = try? JSONValue(encoding: report) else { return .null }
        fields["text"] = .string(text)
        return .object(fields)
    }

    /// The notes' answer: `{"notes": [{"title", "detail"}]}`, in the order given.
    public static func notesAnswer(_ notes: [(title: String, detail: String)]) -> JSONValue {
        .object(["notes": .array(notes.map { .object(["title": .string($0.title), "detail": .string($0.detail)]) })])
    }

    /// The specs, in Help menu order.
    static let specs: [CommandSpec<SuiteHelpDocument>] = [
        .typed("help.report-problem", title: "Report a Problem…",
               summary: "Builds a plain report of the app, its version, macOS, the Mac model and the newest suite crashes, with the note on top. Nothing is sent.",
               kind: .query, params: ReportParams.self, schema: reportParams, result: reportResult,
               example: .object(["app": .string("photo"), "note": .string("The brush lagged.")])) { (doc: inout SuiteHelpDocument, params: ReportParams) throws -> JSONValue in
            doc.answer = doc.provider.report(app: params.app ?? doc.app, note: params.note ?? "")
            return doc.answer
        },
        .typed("help.beta-notes", title: "Beta Notes", summary: "Lists the build's known issues.",
               kind: .query, params: NoParams.self, schema: .none, result: notesResult,
               example: .object([:])) { (doc: inout SuiteHelpDocument, _: NoParams) throws -> JSONValue in
            doc.answer = doc.provider.betaNotes()
            return doc.answer
        },
        .typed("help.welcome", title: "Welcome to AfterGlow", summary: "Opens the welcome tour.",
               kind: .view, params: NoParams.self, schema: .none, example: .object([:]),
               availability: { $0.app == "launcher" ? .available : .unavailable("The welcome tour opens from the AfterGlow launcher.") }
        ) { (_: inout SuiteHelpDocument, _: NoParams) throws -> JSONValue in
            // The Help group opens the tour's window itself; headless there is no window to open.
            throw CatalogError.unavailable(id: "help.welcome", why: "The welcome tour opens in the AfterGlow window, not headless.")
        },
        .typed("help.connect-assistant", title: "Connect an AI Assistant…",
               summary: "Returns the command an MCP client runs to reach the bundled afterglow server, and the JSON block for clients that take one.",
               kind: .query, params: NoParams.self, schema: .none, result: connectResult, example: .object([:]),
               availability: bundled) { (doc: inout SuiteHelpDocument, _: NoParams) throws -> JSONValue in
            doc.answer = doc.provider.connectAssistant()
            return doc.answer
        },
        .typed("help.install-cli", title: "Install Command-Line Tool…",
               summary: "Returns the plan for a link at ~/.local/bin/afterglow to the bundled CLI; with confirm it makes the link. It never replaces a file that isn't its own link.",
               kind: .file, params: InstallParams.self, schema: installParams, result: planResult,
               example: .object(["confirm": .bool(false)]),
               availability: bundled) { (doc: inout SuiteHelpDocument, params: InstallParams) throws -> JSONValue in
            doc.answer = doc.provider.installCLI(confirm: params.confirm ?? false)
            return doc.answer
        },
    ]

    /// The catalog, app `suite`. Empty only if an id were refused.
    public static let catalog = (try? CommandCatalog<SuiteHelpDocument>(app: SuiteHelpDocument.app, specs, history: { _ in History<Int>() }))
        ?? .empty(app: SuiteHelpDocument.app)
}
