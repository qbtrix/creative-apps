// TextSlot.swift: the `text` member of SuiteServices.live. Not live until
// shell-text's ST-8 joins the measurer, font catalog and rasterizer into
// `LiveText`; until then measuring and drawing throw "Text measuring and
// drawing isn't available yet.".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let textIsLive = false

func textSlot(_ c: SlotContext) -> any TextServices {
    FakeText(unavailable: SuiteServices.notConnected("text"))
}
