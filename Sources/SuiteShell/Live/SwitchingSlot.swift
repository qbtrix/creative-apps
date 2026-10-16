// SwitchingSlot.swift: the `switching` member of SuiteServices.live. Not live
// until the switching feature swaps in its launcher; until then the fake
// throws "Not connected yet (switching)." on every switch.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let switchingIsLive = false

func switchingSlot(_ c: SlotContext) -> any AppSwitching {
    FakeSwitching(unavailable: SuiteServices.notConnected("switching"))
}
