// ThumbnailWriter.swift: the live ThumbnailPublishing (UC-15), shared-thumbnails
// ST-2 declares it and ST-5 connects it to CoreAsset's `ThumbnailStore` in
// `folder` (`SuiteLocations.appFolder("Thumbnails", ...)`, so `-SuiteSupportDir`
// moves it) under `budgetBytes`. Until then `publish` says it isn't connected
// and `preview` is nil. Immutable, so Sendable. macOS only.
import Foundation
import SuiteModel

public final class ThumbnailWriter: ThumbnailPublishing {
    /// The store's folder.
    public let folder: String
    /// The most bytes the store keeps before it drops the oldest previews.
    public let budgetBytes: Int

    public init(folder: String, budgetBytes: Int) throws {
        self.folder = folder
        self.budgetBytes = budgetBytes
    }

    public func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String {
        throw .notAvailable("Thumbnails aren't connected yet (shared-thumbnails ST-5).")
    }

    public func preview(for ref: SuiteDocumentRef) async -> Data? { nil }
}
