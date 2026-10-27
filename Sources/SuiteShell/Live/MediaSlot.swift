// MediaSlot.swift: the `media` member of SuiteServices.live. Live since
// shell-media's SM-9 joined its writers and readers into `LiveMedia`, so
// `pending` no longer lists `media` (ShellMediaLiveTests). The `metadata`
// member rides in this slot too: export-pack's XP-7 made `StillMetadata` the
// live MetadataCarrying beside `LiveMedia` (StillMetadataTests).
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let mediaIsLive = true

func mediaSlot(_ c: SlotContext) -> any MediaCoding {
    LiveMedia()
}

func metadataSlot(_ c: SlotContext) -> any MetadataCarrying {
    StillMetadata()
}
