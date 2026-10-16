// LinkingSlot.swift: the `linking` member of SuiteServices.live. Pure, so
// until linked-assets connects it the slot holds the reference fake.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let linkingIsLive = false

func linkingSlot(_ c: SlotContext) -> any AssetLinking {
    FakeLinking()
}
