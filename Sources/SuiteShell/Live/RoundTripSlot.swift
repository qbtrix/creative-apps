// RoundTripSlot.swift: the `roundTrips` member of SuiteServices.live. Not
// live until photo-round-trip swaps in its editor; until then every call
// throws "Not connected yet (photo-round-trip).".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let roundTripsIsLive = false

func roundTripsSlot(_ c: SlotContext) -> any RoundTripEditing {
    FakeRoundTrips(unavailable: SuiteServices.notConnected("roundTrips"))
}
