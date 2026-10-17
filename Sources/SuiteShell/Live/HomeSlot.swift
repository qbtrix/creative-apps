// HomeSlot.swift: the `home` member of SuiteServices.live. HomeBuilder, the
// live builder, with the user's locale and calendar. Pure, so it never
// throws; live since the home window shipped (HM-2a), so `pending` no longer
// lists `home` (SuiteLiveServicesTests).
import Foundation
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let homeIsLive = true

func homeSlot(_ c: SlotContext) -> any HomeBuilding {
    HomeBuilder(creating: creatingSlot(c), locale: .autoupdatingCurrent, calendar: .autoupdatingCurrent)
}
