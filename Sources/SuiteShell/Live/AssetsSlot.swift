// AssetsSlot.swift: the `assets` member of SuiteServices.live. Not live
// until shared-assets swaps in its library; until then every call throws
// "Not connected yet (shared-assets).".
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let assetsIsLive = false

func assetsSlot(_ c: SlotContext) -> any AssetLibrary {
    FakeAssets(unavailable: SuiteServices.notConnected("assets"))
}
