// RoutingSlot.swift: the `routing` member of SuiteServices.live. Routing is
// pure (a file's type to the apps that read it, off the type registry), so the
// reference conformance is the live one: the slot is live and Open…, Open In
// and drops route through it (#1763).
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let routingIsLive = true

func routingSlot(_ c: SlotContext) -> any DocumentRouting {
    FakeRouting()
}
