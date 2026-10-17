// SwitchingSlot.swift: the `switching` member of SuiteServices.live. Live:
// AppLauncher over the AfterGlow bundle that holds this process, whether the
// process is the launcher or one of the apps inside it.
import Foundation
import SuiteModel

/// Whether this slot holds the live conformance; `live` builds `pending` from it.
let switchingIsLive = true

func switchingSlot(_ c: SlotContext) -> any AppSwitching {
    AppLauncher(bundle: launcherBundlePath(), arguments: c.arguments)
}

/// The AfterGlow.app that contains this process; the installed one when the process runs elsewhere.
func launcherBundlePath() -> String {
    let parts = Bundle.main.bundlePath.split(separator: "/", omittingEmptySubsequences: true)
    guard let index = parts.firstIndex(of: "AfterGlow.app") else { return "/Applications/AfterGlow.app" }
    return "/" + parts[...index].joined(separator: "/")
}
