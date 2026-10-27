// ThumbnailPublishing.swift: UC-15, thumbnails for the home (tier 1), and the
// read side the home and Library draw from (shared-thumbnails ST-2).
// Foundation only for `Data`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-15 Thumbnails for the home (tier 1). Live: SuiteShell `ThumbnailWriter`,
/// over CoreAsset's `ThumbnailStore`.
public protocol ThumbnailPublishing: Sendable {
    /// Writes a 512 px PNG; returns its store-relative path,
    /// `thumbnails/<fileKey>.png` (`SuiteDocumentRef.fileKey`).
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String

    /// The newest preview published for `ref`, or nil when there is none.
    /// Never decodes the document.
    func preview(for ref: SuiteDocumentRef) async -> Data?
}
