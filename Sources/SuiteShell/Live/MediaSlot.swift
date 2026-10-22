// MediaSlot.swift: the `media` member of SuiteServices.live. Not live until
// shell-media's SM-9 joins its writers and readers into `LiveMedia`; until
// then every call throws "Movie and image export isn't available yet.".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let mediaIsLive = false

func mediaSlot(_ c: SlotContext) -> any MediaCoding {
    FakeMedia(unavailable: SuiteServices.notConnected("media"))
}
