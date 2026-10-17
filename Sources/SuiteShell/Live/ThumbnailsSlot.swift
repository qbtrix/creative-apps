// ThumbnailsSlot.swift: the `thumbnails` member of SuiteServices.live. Not
// live until recents-open-in swaps in its writer; until then publishing
// throws "Not connected yet (recents-open-in).".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let thumbnailsIsLive = false

func thumbnailsSlot(_ c: SlotContext) -> any ThumbnailPublishing {
    FakeThumbnails(unavailable: SuiteServices.notConnected("thumbnails"))
}
