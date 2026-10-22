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
}

/// The Help commands' target: the app whose Help menu runs them and the provider they read.
public struct SuiteHelpDocument: HeadlessDocument {
    /// The app ("launcher", "photo") and the provider.
    public let app: String, provider: any HelpProviding
    public init(app: String, provider: any HelpProviding) { (self.app, self.provider) = (app, provider) }

    public static let app = "suite"
    public static let openExtensions: [String] = [], exportFormats: [String] = []
    public static var catalog: CommandCatalog<SuiteHelpDocument> { SuiteHelpCatalog.catalog }
    public static func open(_ data: Data, name: String) throws -> Self { throw CatalogError.notBuilt(id: "open", feature: "RP-5") }
    public static func new(_ options: JSONValue) throws -> Self { throw CatalogError.notBuilt(id: "new", feature: "RP-5") }
    public func save() throws -> Data { throw CatalogError.notBuilt(id: "save", feature: "RP-5") }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    public func summary() -> JSONValue { .object(["app": .string(app)]) }
}

/// The suite's Help catalog: `help.report-problem`, `help.beta-notes` and `help.welcome`.
public enum SuiteHelpCatalog {
    /// `help.report-problem`'s params: the app to report on (the document's when left out) and the person's note.
    public struct ReportParams: Codable, Sendable { public var app: String?; public var note: String? }
    /// No params.
    public struct NoParams: Codable, Sendable {}

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

    /// The specs, in Help menu order.
    static let specs: [CommandSpec<SuiteHelpDocument>] = [
        .typed("help.report-problem", title: "Report a Problem…",
               summary: "Builds a plain report of the app, its version, macOS, the Mac model and the newest suite crashes, with the note on top. Nothing is sent.",
               kind: .query, params: ReportParams.self, schema: reportParams, result: reportResult,
               example: .object(["app": .string("photo"), "note": .string("The brush lagged.")])) { (_: inout SuiteHelpDocument, _: ReportParams) throws -> JSONValue in
            throw CatalogError.notBuilt(id: "help.report-problem", feature: "RP-5")
        },
        .typed("help.beta-notes", title: "Beta Notes", summary: "Lists the build's known issues.",
               kind: .query, params: NoParams.self, schema: .none, result: notesResult,
               example: .object([:])) { (_: inout SuiteHelpDocument, _: NoParams) throws -> JSONValue in
            throw CatalogError.notBuilt(id: "help.beta-notes", feature: "RP-5")
        },
        .typed("help.welcome", title: "Welcome to AfterGlow", summary: "Opens the welcome tour.",
               kind: .view, params: NoParams.self, schema: .none, example: .object([:]),
               availability: { $0.app == "launcher" ? .available : .unavailable("The welcome tour opens from the AfterGlow launcher.") }
        ) { (_: inout SuiteHelpDocument, _: NoParams) throws -> JSONValue in
            throw CatalogError.notBuilt(id: "help.welcome", feature: "RP-5")
        },
    ]

    /// The catalog, app `suite`. Empty only if an id were refused.
    public static let catalog = (try? CommandCatalog<SuiteHelpDocument>(app: SuiteHelpDocument.app, specs, history: { _ in History<Int>() }))
        ?? .empty(app: SuiteHelpDocument.app)
}
