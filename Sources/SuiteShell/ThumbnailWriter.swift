// ThumbnailWriter.swift: the live ThumbnailPublishing (UC-15, shared-thumbnails
// ST-5) over CoreAsset's `ThumbnailStore` in `folder` under `budgetBytes`.
// `folder(arguments:home:)` is `<support>/Thumbnails`, a sibling of each app's
// `SuiteLocations.appFolder`, so `-SuiteSupportDir` moves it. Each document's
// preview is keyed by its `fileKey`, so a second publish replaces the first and
// the store's LRU drops the oldest past the budget. Immutable over a Sendable
// store, so Sendable. macOS only.
import CoreAsset
import Foundation
import SuiteModel

public final class ThumbnailWriter: ThumbnailPublishing {
    /// The store's folder.
    public let folder: String
    /// The most bytes the store keeps before it drops the oldest previews.
    public let budgetBytes: Int

    private let store: ThumbnailStore

    /// The suite's previews folder: `<support>/Thumbnails`, under `-SuiteSupportDir` when the arguments name one.
    public static func folder(arguments: [String], home: String) -> String {
        SuiteLocations.appFolder("Thumbnails", arguments: arguments, home: home)
    }

    public init(folder: String, budgetBytes: Int) throws {
        self.folder = folder
        self.budgetBytes = budgetBytes
        store = try ThumbnailStore(folder: URL(fileURLWithPath: folder), budgetBytes: budgetBytes)
    }

    /// Every preview (512 px, so `.medium`) is one size class and one content slot per document, so a publish replaces the last.
    private static func key(for ref: SuiteDocumentRef) -> PreviewKey {
        PreviewKey(asset: SuiteDocumentRef.fileKey(ref.fileID), content: "preview", size: .medium)
    }

    public func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String {
        do {
            try store.write(png, for: Self.key(for: ref), volume: nil, relativePath: nil)
        } catch {
            throw .ioFailed("The preview couldn't be saved: \(error)")
        }
        return "thumbnails/\(SuiteDocumentRef.fileKey(ref.fileID)).png"
    }

    public func preview(for ref: SuiteDocumentRef) async -> Data? {
        try? store.read(Self.key(for: ref))
    }
}
