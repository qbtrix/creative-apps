// PhotoHeadless.swift (command-catalog CC-2 stub; adopt-command-catalog AC-photo fills it): Photo's document with no window.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

/// Photo's headless document for the afterglow CLI and MCP. A stub: an empty catalog, and every entry point throws
/// `CatalogError.notBuilt` naming the slice that fills it.
public struct PhotoHeadless: HeadlessDocument {
    /// The slice that builds this document.
    public static let adoptingSlice = "adopt-command-catalog AC-photo"
    public static let app = "photo", openExtensions: [String] = [], exportFormats: [String] = []
    public static let catalog = CommandCatalog<PhotoHeadless>.empty(app: app)
    public static func open(_ data: Data, name: String) throws -> PhotoHeadless { throw notBuilt("open") }
    public static func new(_ options: JSONValue) throws -> PhotoHeadless { throw notBuilt("new") }
    public func save() throws -> Data { throw Self.notBuilt("save") }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { throw Self.notBuilt("export") }
    public func summary() -> JSONValue { .object(["app": .string(Self.app), "notBuilt": .string(Self.adoptingSlice)]) }
    /// The refusal every entry point throws until the adopting slice lands.
    static func notBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: adoptingSlice) }
}
