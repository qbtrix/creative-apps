// HeadlessDocument.swift (command-catalog CC-1, protocol only): a document driven with no window, and the drop-reader
// seam a host uses to hand `file.drop` its files.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/// One file an export writes: the name to offer ("poster.png"), the format id ("png") and the bytes.
public struct ExportedFile: Hashable, Sendable {
    public var suggestedName: String; public var format: String; public var data: Data
    public init(suggestedName: String, format: String, data: Data) { (self.suggestedName, self.format, self.data) = (suggestedName, format, data) }
}

/// A document an app opens, edits, saves and exports with no window: what the CLI, MCP and the real-jobs suites drive.
public protocol HeadlessDocument: Sendable {
    /// The app's name ("photo").
    static var app: String { get }
    /// The extensions `open` reads, the native one first, then imports.
    static var openExtensions: [String] { get }
    /// The format ids `export` writes.
    static var exportFormats: [String] { get }
    /// Every command the app runs on this document.
    static var catalog: CommandCatalog<Self> { get }
    /// Opens a file's bytes; `name` is its file name.
    static func open(_ data: Data, name: String) throws -> Self
    /// A new document from `options` (size, preset and the like).
    static func new(_ options: JSONValue) throws -> Self
    /// The document in its native format.
    func save() throws -> Data
    /// The document exported as `format` with `options`.
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile]
    /// What `afterglow <app> open` prints.
    func summary() -> JSONValue
}

/// A headless document that takes `file.drop`: the host reads the dropped files through its own IO and hands their
/// bytes over, keyed by the path the step names, before the step runs; the document never reads the disk itself.
public protocol HeadlessDropReceiver: HeadlessDocument {
    /// The dropped files' bytes by path, for the next `file.drop` steps.
    mutating func receiveDropped(_ files: [String: Data])
}
