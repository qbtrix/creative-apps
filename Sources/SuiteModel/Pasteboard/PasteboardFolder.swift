// PasteboardFolder.swift (clipboard-interop CB-1 stub, CB-4 body): the CLI's pasteboard (`--pasteboard <dir>`),
// one file per type, so copy and paste jobs run on Linux with no system pasteboard.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A folder that stands in for the system pasteboard. Until CB-4, writing does nothing and reading finds nothing.
public struct PasteboardFolder: Sendable {
    /// The folder the items live in.
    public let url: URL

    public init(_ url: URL) { self.url = url }

    /// Replaces the folder's items with `items`, one file per type, in order.
    public func write(_ items: [TypedData]) throws {}

    /// The items the folder holds, in the order they were written; a file the folder didn't write is ignored.
    public func read() throws -> [TypedData] { [] }
}
