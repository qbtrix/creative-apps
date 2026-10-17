// RecentsSlot.swift: the `recents` member of SuiteServices.live. Live: the
// shared recents list in the support folder's recents.json (StoreRecents).
// Each write posts a store change; a change posted by another process
// re-reads the list, so this process's recents follow the others'.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let recentsIsLive = true

func recentsSlot(_ c: SlotContext) -> any RecentWork {
    let recents = StoreRecents(store: c.store, onWrite: StoreWatcher.post)
    StoreWatcher.observe("recents.json") { Task { await recents.externalChange() } }
    return recents
}
