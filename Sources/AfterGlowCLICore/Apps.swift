// Apps.swift (afterglow-cli CL-2): the app registry. Each app's
// HeadlessDocument type, erased to a HeadlessApp so the router can list and
// pick one by name, and HeadlessSession, one open document of any app. Both
// forward to the app's catalog, so a command runs once the app adopts it
// (adopt-command-catalog) and command-catalog CC-7 fills `run`. Photo and Halo
// open on their live services with SuiteText's LiveText on macOS, so their text
// commands draw (#5193, #5280); on Linux they keep their fakes.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@_exported import SuiteKernel
import DesignModel
import FlareModel
import HaloModel
import LibraryModel
import PhotoModel
import SuiteImaging
#if canImport(SuiteText)
import SuiteText
#endif

/// One app's headless document type, erased so the router can list it and open files with it.
public struct HeadlessApp: Sendable {
    /// The app's name ("photo"), the extensions `open` reads (native first) and the formats `export` writes.
    public let name: String; public let openExtensions: [String]; public let exportFormats: [String]
    private let describe: @Sendable () -> [CommandDescription]
    private let open: @Sendable (Data, String) throws -> HeadlessSession
    private let make: @Sendable (JSONValue) throws -> HeadlessSession

    /// The app whose document is `type`.
    public init<D: HeadlessDocument>(_ type: D.Type) { self.init(type, open: D.open, new: D.new) }

    /// The app whose document is `type`, opened and made by `open` and `new` in place of the type's own: for a
    /// document that needs a value its type can't make, as the suite's Help document needs its provider.
    init<D: HeadlessDocument>(_ type: D.Type, open: @escaping @Sendable (Data, String) throws -> D,
                              new: @escaping @Sendable (JSONValue) throws -> D) {
        (name, openExtensions, exportFormats) = (D.app, D.openExtensions, D.exportFormats)
        describe = { D.catalog.describeAll() }
        self.open = { data, name in HeadlessSession(app: D.app, box: TypedSession(document: try open(data, name))) }
        make = { options in HeadlessSession(app: D.app, box: TypedSession(document: try new(options))) }
    }

    /// Every command the app runs, by id.
    public func describeAll() -> [CommandDescription] { describe() }

    /// Opens a file's bytes as this app's document; `name` is its file name. Throws what the app's `open` throws.
    public func session(open data: Data, name: String) throws -> HeadlessSession { try open(data, name) }
    /// A new document of this app from `options`. Throws what the app's `new` throws.
    public func session(new options: JSONValue) throws -> HeadlessSession { try make(options) }
}

/// One open document of any app: run commands on it, then save or export it.
public struct HeadlessSession: Sendable {
    /// The app whose document this is.
    public let app: String
    private var box: any SessionBox

    init(app: String, box: any SessionBox) { (self.app, self.box) = (app, box) }

    /// Whether the command `id` can run on the document now, and if not the app's why-not.
    public func availability(_ id: String) -> Availability { box.availability(id) }
    /// Runs one step on the document through the app's catalog.
    public mutating func run(_ step: CommandEnvelope) throws(CatalogError) -> CommandOutcome { try box.run(step) }
    /// Runs `steps` in order, stopping at the first refusal; `atomic` puts the document back when one stops it.
    public mutating func runBatch(_ steps: [CommandEnvelope], atomic: Bool) -> BatchReport { box.runBatch(steps, atomic: atomic) }
    /// The document in its app's native format.
    public func save() throws -> Data { try box.save() }
    /// The document exported as `format` with `options`.
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { try box.export(format, options: options) }
    /// What `afterglow <app> open` prints.
    public func summary() -> JSONValue { box.summary() }
}

/// The session's document behind its type.
protocol SessionBox: Sendable {
    func availability(_ id: String) -> Availability
    mutating func run(_ step: CommandEnvelope) throws(CatalogError) -> CommandOutcome
    mutating func runBatch(_ steps: [CommandEnvelope], atomic: Bool) -> BatchReport
    func save() throws -> Data
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile]
    func summary() -> JSONValue
}

/// A session's document of a known type, run through that type's catalog.
struct TypedSession<D: HeadlessDocument>: SessionBox {
    var document: D
    func availability(_ id: String) -> Availability { D.catalog.availability(id, on: document) }
    mutating func run(_ step: CommandEnvelope) throws(CatalogError) -> CommandOutcome { try D.catalog.run(step, on: &document) }
    mutating func runBatch(_ steps: [CommandEnvelope], atomic: Bool) -> BatchReport { D.catalog.runBatch(steps, on: &document, atomic: atomic) }
    func save() throws -> Data { try document.save() }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { try document.export(format, options: options) }
    func summary() -> JSONValue { document.summary() }
}

/// The apps the CLI drives.
public enum Apps {
    /// The five apps, in the suite's order: photo, design, flare, halo, library.
    public static let all: [HeadlessApp] = [
        HeadlessApp(PhotoHeadless.self, open: { try PhotoHeadless.open($0, name: $1, services: photoServices) },
                    new: { try PhotoHeadless.new($0, services: photoServices) }),
        HeadlessApp(DesignHeadless.self), HeadlessApp(FlareHeadless.self),
        HeadlessApp(HaloHeadless.self, open: { try HaloHeadless.open($0, name: $1, services: haloServices) },
                    new: { try HaloHeadless.new($0, services: haloServices) }),
        HeadlessApp(LibraryHeadless.self),
    ]

    /// Photo's live services, drawing text with SuiteText's LiveText where the build has it (macOS).
    static var photoServices: PhotoServices {
        var services = PhotoServices.live
        #if canImport(SuiteText)
        services.text = LiveText()
        #endif
        return services
    }

    /// Halo's live services, drawing text with LiveText through HaloTextAdapter where the build has it (macOS).
    static var haloServices: HaloServices {
        var services = HaloServices.live
        #if canImport(SuiteText)
        services.text = HaloTextAdapter(LiveText())
        #endif
        return services
    }
    /// The suite's Help commands ("suite"), over the `.suitehelp` files `HelpReports` reads. Never in `all`.
    public static let suite = HeadlessApp(SuiteHelpDocument.self, open: { data, _ in try HelpReports.open(data) }, new: HelpReports.new)
    /// The fake app ("fake", SuiteKernel's FakeCanvasDocument). Never in `all`; the tests add it.
    public static let fake = HeadlessApp(FakeCanvasDocument.self)
    /// The tone fake ("fake-tone", SuiteImaging's FakeToneDocument): one picture's tone settings, for RJ-X41.
    public static let fakeTone = HeadlessApp(FakeToneDocument.self)

    /// The app called `name` in `apps`, nil when there is none.
    public static func named(_ name: String, in apps: [HeadlessApp]) -> HeadlessApp? { apps.first { $0.name == name } }
}
