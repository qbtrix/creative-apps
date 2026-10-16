// Links.swift: what kind an asset is, a placed asset's link back to the
// suite's asset library, and that link's status. Foundation free,
// Linux-safe, Sendable.

/// The kinds of asset the suite's library holds.
public enum AssetKind: String, Codable, CaseIterable, Sendable { case color, vector, image, animation }

/// A placed asset's memory of where it came from. Stored inside the host document.
public struct AssetLink: Codable, Hashable, Sendable {
    public var assetID: String
    public var kind: AssetKind
    public var placedRevision: Int
    public init(assetID: String, kind: AssetKind, placedRevision: Int) {
        self.assetID = assetID; self.kind = kind; self.placedRevision = placedRevision
    }
}

/// Where a placed asset stands against the library's copy.
public enum LinkStatus: Equatable, Sendable { case current, updateAvailable(revision: Int), missing }
