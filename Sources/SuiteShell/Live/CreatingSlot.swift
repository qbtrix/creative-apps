// CreatingSlot.swift: the `creating` member of SuiteServices.live, the live
// `SuiteCreating`. The flag stays false: SuiteLiveServicesTests expects `creating` pending.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let creatingIsLive = false

func creatingSlot(_ c: SlotContext) -> any DocumentCreating {
    SuiteCreating()
}
