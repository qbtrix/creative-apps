// PasteboardSlot.swift: the `pasteboard` member of SuiteServices.live. Pure,
// so it never throws; live since clipboard-interop's coder landed (CB-4),
// so `pending` no longer lists `pasteboard` (SuiteLiveServicesTests).
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let pasteboardIsLive = true

func pasteboardSlot(_ c: SlotContext) -> any PasteboardCoding {
    SuitePasteboardCoding()
}
