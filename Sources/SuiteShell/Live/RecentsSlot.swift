// RecentsSlot.swift: the `recents` member of SuiteServices.live. Live: the
// shared recents list in the support folder's recents.json (StoreRecents).
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let recentsIsLive = true

func recentsSlot(_ c: SlotContext) -> any RecentWork {
    StoreRecents(store: c.store)
}
