// FlareHeadless.swift (command-catalog CC-2 stub; adopt-command-catalog AC-flare fills it): Flare's document with no window.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// Flare's headless document for the afterglow CLI and MCP. A stub: an empty catalog, and every entry point throws
/// `CatalogError.notBuilt` naming the slice that fills it.
public struct FlareHeadless: HeadlessDocument {
    /// The slice that builds this document.
    public static let adoptingSlice = "adopt-command-catalog AC-flare"
    public static let app = "flare", openExtensions: [String] = [], exportFormats: [String] = []
    public static let catalog = CommandCatalog<FlareHeadless>.empty(app: app)
    public static func open(_ data: Data, name: String) throws -> FlareHeadless { throw notBuilt("open") }
    public static func new(_ options: JSONValue) throws -> FlareHeadless { throw notBuilt("new") }
    public func save() throws -> Data { throw Self.notBuilt("save") }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { throw Self.notBuilt("export") }
    public func summary() -> JSONValue { .object(["app": .string(Self.app), "notBuilt": .string(Self.adoptingSlice)]) }
    /// The refusal every entry point throws until the adopting slice lands.
    static func notBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: adoptingSlice) }
}
