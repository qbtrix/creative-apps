// Live/LiveCulling.swift: spine stub. The cull feature replaces this file
// with the live conformance and sets `unavailable` to nil; until then every
// call throws the reason, and controls that need it are disabled with it.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveCulling: PhotoCulling {
    public static let unavailable: String? = "Rating keys aren't connected yet (cull)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    public init() {}

    public func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem] {
        throw Self.notBuilt
    }

    public func advance(from id: String, before: [String], after: [String]) -> String? { id }
}
