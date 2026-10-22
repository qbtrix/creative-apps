// TestDefaults.swift: the defaults every window this test process hosts reads,
// registered once before the first one draws. `ApplePersistenceIgnoreState`
// is the journeys' launch flag: with it a hosted window's `.autosaveRecovery`
// gets no folder (Flare's FlareAutosaveAdapter, Design's history area), so it
// neither writes recovery copies into the user's real suite folder after an
// edit nor offers a stale one as an alert sheet that then covers every later
// window in this run or the next one. Registered, never set: the registration
// domain lives only in this process and leaves nothing in the helper's
// defaults on disk. The windows read the default once per process (a static),
// so each host that can draw one (RenderBudgetWindow, `render(_:scheme:)`)
// touches `registered` before it builds its window.
import Foundation

enum TestDefaults {
    static let registered: Void = {
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
    }()
}
