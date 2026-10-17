// RoutingSlot.swift: the `routing` member of SuiteServices.live. Pure, so
// until recents-open-in connects it the slot holds the reference fake.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let routingIsLive = false

func routingSlot(_ c: SlotContext) -> any DocumentRouting {
    FakeRouting()
}
