// LibraryHeadless+Shown.swift (folders FO-6): the "json" export with `options.contents` "shown", what a real job
// checks after view.show-folder (RJ-L53): the folder rule's path and subfolders choice (absent while none is on)
// and the file name of each photo the grid shows, in the grid's order. `original` is Show Original's state, true or
// false and never absent (command-state CS-15, RJ-X61), so an agent reads the toggle back either way. A CLI run
// starts with it off: it is view state the catalog file doesn't keep. Linux-safe.
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
        var original: Bool
        var shown: [String]
    }

    /// Whether `options` asks the "json" export for the shown photos instead of the catalog file.
    static func wantsShown(_ options: JSONValue) -> Bool {
        (try? options.decode(ShownRequest.self).contents) == "shown"
    }

    /// The folder rule, Show Original's state, and the shown photos' file names, as JSON.
    func shownFile() throws -> Data {
        let byID = Dictionary(library.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let names = library.order.compactMap { byID[$0] }.map { p in
            p.path.flatMap { $0.split(separator: "/").last.map(String.init) } ?? p.name
        }
        let scope = library.activeFilter.folder
        do {
            return try JSONEncoder().encode(Shown(folder: scope?.path, subfolders: scope?.subfolders,
                                                 original: library.showsOriginal, shown: names))
        } catch {
            throw CatalogError.failed(id: "export.json", message: "\(error)")
        }
    }
}
