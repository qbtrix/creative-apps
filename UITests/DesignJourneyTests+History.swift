// DesignJourneyTests+History.swift: the Journey steps of design/autosave-history
// (docs/blueprints/design/features/autosave-history.md), RJ-D20. View > Show History (DA-2)
// shows SuiteUI's History panel (`suite.history`, rows `suite.history.row.<n>`, 0 for "Open")
// at the window's trailing edge; the toolbar's History button comes with DA-3.
// 1. Open `card.design`, make 12 edits, click History: the panel lists "Open" and 12 steps.
// 2. Click step 2: the canvas shows the card after two edits; later rows dim.
// 3. Make one more edit: the dimmed rows go.
// 4. Force-quit with the edit unsaved, relaunch: the alert offers "Restore the autosaved changes
//    to “card.design”?"; Restore shows the 3-step card, marked edited.
// DA-2 writes it skipped: the jump and the recovery bytes are stubs until DA-5, the autosave until
// SuiteUI's AH-8, and DA-7 turns it on over live services.
import XCTest

final class DesignHistoryJourneyTests: XCTestCase {
    /// Steps 1 to 4: twelve edits, a jump to step 2, one more edit, then a force-quit and Restore.
    @MainActor func testJumpAndRecover() throws { throw XCTSkip("waits on DA-7: the jump and autosave are stubs") }
}
