// TestDefaults.swift: the defaults every window this test process hosts reads,
// registered once before the first one draws. `ApplePersistenceIgnoreState`
// is the journeys' launch flag: with it FlareRecovery keeps no recovery file,
// so a hosted FlareWindow neither writes the user's real
// Application Support/Flare/Recovery.flare after an edit nor offers a stale
// one as an alert sheet that then covers every later Flare window in this
// run or the next one. Registered, never set: the registration domain lives
// only in this process and leaves nothing in the helper's defaults on disk.
// FlareRecovery reads the default once per process (a static), so each host
// that can draw a FlareWindow (RenderBudgetWindow, `render(_:scheme:)`)
// touches `registered` before it builds its window.
import Foundation

enum TestDefaults {
    static let registered: Void = {
        UserDefaults.standard.register(defaults: ["ApplePersistenceIgnoreState": true])
    }()
}
