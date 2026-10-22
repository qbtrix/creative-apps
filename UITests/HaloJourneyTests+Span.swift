// HaloJourneyTests+Span.swift: HJ-TK (timeline-keys, packet
// docs/blueprints/suiteui/features/timeline-keys.md). Three text layers: drag
// the second bar's body 6 frames right and the third's 12, then the third's
// out end 12 frames left; each drag is one undo step and the keys move with
// their bars. The strip slides and trims (TK-4), but `layer.slide` and
// `layer.trim` are built in TK-6 and wired to the window in TK-9, so the
// journey is skipped until then. Shots are `halo-tk-<step>`.
import XCTest

final class HaloSpanJourneyTests: XCTestCase {
    /// HJ-TK: slide two layers' bars and trim one, one undo step each.
    @MainActor func testSlideAndTrimLayers() throws {
        throw XCTSkip("waits on TK-6 and TK-9: layer.slide and layer.trim, wired to Halo's window")
    }
}
