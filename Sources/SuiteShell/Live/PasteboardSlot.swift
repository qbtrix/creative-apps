// PasteboardSlot.swift: the `pasteboard` member of SuiteServices.live. Pure,
// so until clipboard-drag connects it the slot holds the reference fake.
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let pasteboardIsLive = false

func pasteboardSlot(_ c: SlotContext) -> any PasteboardCoding {
    FakePasteboard()
}
