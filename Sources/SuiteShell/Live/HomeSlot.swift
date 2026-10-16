// HomeSlot.swift: the `home` member of SuiteServices.live. HomeBuilder, the
// live builder, with the user's locale and calendar. Pure, so it never
// throws; the flag stays false until the home window ships, so `pending`
// keeps saying "The Home window isn't available yet." (SuiteLiveServicesTests).
import Foundation
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let homeIsLive = false

func homeSlot(_ c: SlotContext) -> any HomeBuilding {
    HomeBuilder(creating: creatingSlot(c), locale: .autoupdatingCurrent, calendar: .autoupdatingCurrent)
}
