// PreferencesSlot.swift: the `preferences` member of SuiteServices.live. Live:
// the suite preferences in the support folder's preferences.json
// (StorePreferences). The launcher is the only writer in the beta, so no
// StoreWatcher is attached yet; switching attaches `externalChange()` when
// a second process writes.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let preferencesIsLive = true

func preferencesSlot(_ c: SlotContext) -> any PreferencesStoring {
    StorePreferences(store: c.store)
}
