// Live/LiveCatalogCoding.swift: spine stub. The persist feature replaces this file
// with the live conformance and sets `unavailable` to nil. Until then it
// does what needs no file (samples through `SampleImage`, pure rules) and
// throws its reason for anything that needs the feature, so the controls
// that need it are disabled with that reason.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveCatalogCoding: CatalogCoding {
    public static let unavailable: String? = "Saving the catalog isn't connected yet (persist)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    public init() {}

    public func encode(_ photos: [PhotoItem]) throws -> Data { throw Self.notBuilt }
    public func decode(_ data: Data) throws -> [PhotoItem] { throw Self.notBuilt }
}
