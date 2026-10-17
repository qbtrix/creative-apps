// SettingsSlot.swift: the `settings` member of SuiteServices.live. Not live
// until the settings feature swaps in its route; until then opening a pane
// throws "Not connected yet (settings).".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let settingsIsLive = false

func settingsSlot(_ c: SlotContext) -> any SettingsRouting {
    FakeSettingsRoute(unavailable: SuiteServices.notConnected("settings"))
}
