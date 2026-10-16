// HandOffSlot.swift: the `sending` and `receiving` members of
// SuiteServices.live, one object for both. Not live until the switching
// feature swaps in its transport; until then every call throws
// "Not connected yet (switching).".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let handOffIsLive = false

func handOffSlot(_ c: SlotContext) -> any HandOffSending & HandOffReceiving {
    FakeHandOffs(unavailable: SuiteServices.notConnected("sending"))
}
