// LibraryHeadless+Shown.swift (folders FO-6): the "json" export with `options.contents` "shown", what a real job
// checks after view.show-folder (RJ-L53): the folder rule's path and subfolders choice (absent while none is on)
// and the file name of each photo the grid shows, in the grid's order. `original` is true while Show Original is on
// (command-state CS-15, RJ-X61) and absent otherwise, so an agent reads the toggle back. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension LibraryHeadless {
    struct ShownRequest: Decodable { var contents: String? }
    struct Shown: Encodable {
        var folder: String?
        var subfolders: Bool?
        var original: Bool?
        var shown: [String]
    }

    /// Whether `options` asks the "json" export for the shown photos instead of the catalog file.
    static func wantsShown(_ options: JSONValue) -> Bool {
        (try? options.decode(ShownRequest.self).contents) == "shown"
    }

    /// The folder rule, Show Original while it is on, and the shown photos' file names, as JSON.
    func shownFile() throws -> Data {
        let byID = Dictionary(library.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let names = library.order.compactMap { byID[$0] }.map { p in
            p.path.flatMap { $0.split(separator: "/").last.map(String.init) } ?? p.name
        }
        let scope = library.activeFilter.folder
        do {
            return try JSONEncoder().encode(Shown(folder: scope?.path, subfolders: scope?.subfolders,
                                                 original: library.showsOriginal ? true : nil, shown: names))
        } catch {
            throw CatalogError.failed(id: "export.json", message: "\(error)")
        }
    }
}
