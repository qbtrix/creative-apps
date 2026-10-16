// AssetLinking.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.

/// UC-9 Placed assets keep their link (tier 3). Pure over the index.
public protocol AssetLinking: Sendable {
    func link(to asset: SuiteAsset) -> AssetLink
    func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus
    /// The link after Update; nil when there is nothing newer.
    func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink?
}
