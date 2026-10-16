// AssetLibrary.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-8 The shared asset and colour library (tier 2). Live: `FileStore` over `assets/`.
public protocol AssetLibrary: Sendable {
    func index() async throws(SuiteError) -> AssetIndex
    func add(_ draft: AssetDraft, id: String, at date: Date) async throws(SuiteError) -> SuiteAsset
    /// New payload or colour; the revision goes up by one.
    func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) async throws(SuiteError) -> SuiteAsset
    func remove(_ id: String) async throws(SuiteError)
    func payload(of asset: SuiteAsset) async throws(SuiteError) -> Data
    /// Assets added from this document, so its app can offer Update Asset.
    func assets(fromFileID fileID: String) async throws(SuiteError) -> [SuiteAsset]
    func changes() async -> AsyncStream<Int>
}
