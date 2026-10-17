// HandOffSlot.swift: the `sending` and `receiving` members of
// SuiteServices.live, one object for both. Live: StoreHandOffs over the
// support folder's handoffs/, delivering through HandOffTransport.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let handOffIsLive = true

func handOffSlot(_ c: SlotContext) -> any HandOffSending & HandOffReceiving {
    StoreHandOffs(store: c.store, from: c.app, deliver: HandOffTransport.deliver)
}
