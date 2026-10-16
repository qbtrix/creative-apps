// FakeLinking.swift: the reference AssetLinking (UC-9), pure over the index.
// A link is current, has a newer revision to update to, or is missing.
// Pure, so it takes no `unavailable:` (packet correction 6).

public struct FakeLinking: AssetLinking {
    public init() {}

    public func link(to asset: SuiteAsset) -> AssetLink {
        AssetLink(assetID: asset.id, kind: asset.kind, placedRevision: asset.revision)
    }

    public func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus {
        guard let a = index.asset(link.assetID) else { return .missing }
        return a.revision > link.placedRevision ? .updateAvailable(revision: a.revision) : .current
    }

    public func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink? {
        guard case .updateAvailable(let r) = status(of: link, in: index) else { return nil }
        return AssetLink(assetID: link.assetID, kind: link.kind, placedRevision: r)
    }
}
