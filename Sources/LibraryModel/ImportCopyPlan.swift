// ImportCopyPlan.swift (catalog-files LC-1 stub, LC-5 body): where Copy on import puts each photo (packet
// docs/blueprints/library/features/catalog-files.md). Pure: the plan names one destination per source under
// `copyTo` (in `yyyy/yyyy-MM-dd` folders by the capture date, else the file date, when `byDate`), unique by
// SuiteModel's `UniqueFileNames` against the files already there and the plan's own, so nothing is overwritten.
// The live importer copies, checks sizes and renames into place. LC-1: the shape only; the plan is empty.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
    /// a path `exists` says is taken, nor one an earlier step took. LC-1: none.
    public static func plan(_ sources: [(path: String, captured: Date?, modified: Date)], options: ImportCopyOptions,
                            exists: (String) -> Bool) -> [ImportCopyStep] {
        []
    }
}
