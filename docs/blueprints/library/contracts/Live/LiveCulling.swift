// Live/LiveCulling.swift: spine stub. The cull feature replaces this file
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

public struct LiveCulling: PhotoCulling {
    public static let unavailable: String? = "Rating keys aren't connected yet (cull)."
    static var notBuilt: LibraryError { .invalid(unavailable ?? "") }
    public init() {}

    /// The plain rules already work (the inspector's rating has since #750).
    public func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem] {
        try FakeCulling().apply(change, to: ids, in: items)
    }

    public func advance(from id: String, before: [String], after: [String]) -> String? {
        FakeCulling().advance(from: id, before: before, after: after)
    }
}
