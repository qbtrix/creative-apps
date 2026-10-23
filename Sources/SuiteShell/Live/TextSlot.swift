// TextSlot.swift: the `text` member of SuiteServices.live. LiveText, the
// Core Text measurer, font catalog and rasterizer joined (shell-text ST-8);
// live, so `pending` no longer lists `text` (ShellTextLiveTests).
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let textIsLive = true

func textSlot(_ c: SlotContext) -> any TextServices {
    LiveText()
}
