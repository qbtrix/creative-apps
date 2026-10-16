// PreferencesSlot.swift: the `preferences` member of SuiteServices.live. Not
// live until the settings feature swaps in its store; until then every call
// throws "Not connected yet (settings).".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let preferencesIsLive = false

func preferencesSlot(_ c: SlotContext) -> any PreferencesStoring {
    FakePreferences(unavailable: SuiteServices.notConnected("preferences"))
}
