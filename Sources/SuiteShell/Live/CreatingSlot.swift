// CreatingSlot.swift: the `creating` member of SuiteServices.live, the live
// `SuiteCreating`. Live since the home window shipped (HM-2a), so `pending`
// no longer lists `creating` (SuiteLiveServicesTests).
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let creatingIsLive = true

func creatingSlot(_ c: SlotContext) -> any DocumentCreating {
    SuiteCreating()
}
