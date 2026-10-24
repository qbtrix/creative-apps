// PasteboardFolder.swift (clipboard-interop CB-1 stub, CB-4 body): the CLI's pasteboard (`--pasteboard <dir>`),
// one file per type, so copy and paste jobs run on Linux with no system pasteboard. A manifest,
// `pasteboard.json`, lists the files in order with their full type ids; a file it doesn't list is not on the
// pasteboard, so a stray file in the folder is ignored and an own type keeps its id whatever its extension.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A folder that stands in for the system pasteboard.
public struct PasteboardFolder: Sendable {
    /// The folder the items live in.
    public let url: URL

    public init(_ url: URL) { self.url = url }

    /// One file on the pasteboard: its name in the folder and the type it holds.
    struct Entry: Codable, Equatable, Sendable {
        var file: String
        var type: String
    }

    /// The manifest's name; it is never an item.
    static let manifestName = "pasteboard.json"

    /// The extension a type's file gets, so a person can open it; an unlisted type (an app's own layers) is `.data`.
    static let extensions: [SuiteTypeID: String] = [
        .png: "png", .tiff: "tiff", .jpeg: "jpg", .heic: "heic", .svg: "svg", .plainText: "txt",
        .fileURL: "url", .assetEnvelope: "json",
    ]

    /// Replaces the folder's items with `items`, one file per type, in order.
    public func write(_ items: [TypedData]) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let old = manifest()
        var entries: [Entry] = []
        for item in items {
            let entry = Entry(file: "\(entries.count).\(Self.extensions[item.type] ?? "data")", type: item.type.rawValue)
            try item.data.write(to: url.appendingPathComponent(entry.file))
            entries.append(entry)
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(entries).write(to: url.appendingPathComponent(Self.manifestName))
        for stale in old where !entries.contains(where: { $0.file == stale.file }) {
            try? FileManager.default.removeItem(at: url.appendingPathComponent(stale.file))
        }
    }

    /// The items the folder holds, in the order they were written; a file the folder didn't write is ignored.
    public func read() throws -> [TypedData] {
        try manifest().map { entry in
            TypedData(type: SuiteTypeID(rawValue: entry.type), data: try Data(contentsOf: url.appendingPathComponent(entry.file)))
        }
    }

    /// The manifest's entries, or none when the folder has no readable manifest.
    func manifest() -> [Entry] {
        guard let data = try? Data(contentsOf: url.appendingPathComponent(Self.manifestName)) else { return [] }
        let entries = (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
        return entries.filter { !$0.file.contains("/") && !$0.file.hasPrefix(".") && $0.file != Self.manifestName }
    }
}
