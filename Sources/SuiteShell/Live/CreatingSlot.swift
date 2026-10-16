// CreatingSlot.swift: the `creating` member of SuiteServices.live. Pure, so
// until the home feature connects it the slot holds the reference fake.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let creatingIsLive = false

func creatingSlot(_ c: SlotContext) -> any DocumentCreating {
    FakeCreating()
}
