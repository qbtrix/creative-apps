// AfterGlowJourneyTests+ControlState.swift: toggles report their state in
// `suite.controls` (command-state packet, CS-1 wrote it, CS-15 runs it).
// `testTogglesReportState`: in Library's Develop inspector, press Show
// Original; `suite.controls` lists `library.develop.original` with
// `selected: true`, and with `selected: false` after a second press. Until
// Library builds Show Original as a toggle (CS-library-1) the entry carries no
// `selected`, so the journey skips naming that slice.
import XCTest

extension AfterGlowJourneyTests {
    /// CS-15: Show Original reports on, then off, in `suite.controls`.
    @MainActor func testTogglesReportState() throws {
        throw XCTSkip("waits on CS-library-1")
    }
}
