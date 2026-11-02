// ImportCopyPlan.swift (catalog-files LC-1 stub, LC-5 body): where Copy on import puts each photo, under `copyTo`
// (in `yyyy/yyyy-MM-dd` by the capture date, else the file date, when `byDate`), unique by SuiteModel's
// `UniqueFileNames`, so nothing is overwritten. The dated folder is the UTC day, written by hand like the
// status text's dates so Linux and macOS agree. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

/// The import sheet's copy choice: nil `copyTo` adds the photos in place.
public struct ImportCopyOptions: Hashable, Codable, Sendable {
    public var copyTo: String?
    public var byDate: Bool
    public init(copyTo: String? = nil, byDate: Bool = false) { (self.copyTo, self.byDate) = (copyTo, byDate) }
}

/// One file to copy: its path and the path the copy lands at.
public struct ImportCopyStep: Hashable, Sendable {
    public var source: String
    public var destination: String
    public init(source: String, destination: String) { (self.source, self.destination) = (source, destination) }
}

/// The copy plan of an import.
public enum ImportCopyPlan {
    /// One step per source, in order, when `options.copyTo` is set; none when it is nil. A destination is never
    /// a path `exists` says is taken, nor one an earlier step took.
    public static func plan(_ sources: [(path: String, captured: Date?, modified: Date)], options: ImportCopyOptions,
                            exists: (String) -> Bool) -> [ImportCopyStep] {
        guard let root = options.copyTo else { return [] }
        let base = root.hasSuffix("/") && root.count > 1 ? String(root.dropLast()) : root
        var taken: [String: Set<String>] = [:]
        return sources.map { source in
            let folder = options.byDate ? base + "/" + datedFolder(source.captured ?? source.modified) : base
            let (stem, ext) = split(source.path)
            var names = taken[folder] ?? []
            var name = UniqueFileNames.name(stem, extension: ext, among: names)
            var tries = 0
            while exists(folder + "/" + name), tries < maxTries {
                names.insert(name)
                name = UniqueFileNames.name(stem, extension: ext, among: names)
                tries += 1
            }
            names.insert(name)
            taken[folder] = names
            return ImportCopyStep(source: source.path, destination: folder + "/" + name)
        }
    }

    /// How many taken names one file skips past before the plan stops asking (the copy then refuses to overwrite).
    static let maxTries = 10_000

    /// "2026/2026-10-21" for a date on that UTC day; "Undated" for one too far out to write.
    static func datedFolder(_ date: Date) -> String {
        let day = LibraryCatalog.dayText(date, utcOffset: 0)
        return day.isEmpty ? "Undated" : String(day.dropLast(6)) + "/" + day
    }

    /// "IMG_0001.jpg" in "/card/IMG_0001.jpg" as ("IMG_0001", "jpg"); a name with no dot, or only a leading one,
    /// has no extension.
    static func split(_ path: String) -> (stem: String, ext: String) {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return (name, "") }
        return (String(name[..<dot]), String(name[name.index(after: dot)...]))
    }
}
