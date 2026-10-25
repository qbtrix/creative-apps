// ThumbnailsSlot.swift: the `thumbnails` member of SuiteServices.live. Live
// (shared-thumbnails ST-7): the suite's previews in `<support>/Thumbnails`
// (ThumbnailWriter), which Photo publishes to after each save and the home
// reads for its Recent cards. CoreAsset's store answers only what its own
// ledger knows, so a process that opened it before another's publish would
// miss that preview; `SharedThumbnails` reopens the store on a miss and asks
// again. A store that can't open throws its reason on publish and previews
// nothing, so the home shows each app's mark. macOS only.
import Foundation
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let thumbnailsIsLive = true

func thumbnailsSlot(_ c: SlotContext) -> any ThumbnailPublishing {
    SuiteServices.liveThumbnails(support: c.support)
}

extension SuiteServices {
    /// The most bytes the suite's previews keep before the oldest are dropped.
    public static let thumbnailsBudget = 256 * 1024 * 1024

    /// The suite's previews in `support`'s Thumbnails folder; a fake that says why when the store won't open.
    public static func liveThumbnails(support: String) -> any ThumbnailPublishing {
        do {
            return SharedThumbnails(writer: try ThumbnailWriter(folder: support + "/Thumbnails", budgetBytes: thumbnailsBudget))
        } catch {
            return FakeThumbnails(unavailable: "Previews can't be kept: \(error.localizedDescription)")
        }
    }
}

/// A ThumbnailWriter that sees other processes' publishes: a preview its
/// store doesn't know is read again through a store opened now.
final class SharedThumbnails: ThumbnailPublishing {
    private let writer: ThumbnailWriter

    init(writer: ThumbnailWriter) { self.writer = writer }

    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String {
        try await writer.publish(png: png, for: ref)
    }

    func preview(for ref: SuiteDocumentRef) async -> Data? {
        if let known = await writer.preview(for: ref) { return known }
        guard let now = try? ThumbnailWriter(folder: writer.folder, budgetBytes: writer.budgetBytes) else { return nil }
        return await now.preview(for: ref)
    }
}
