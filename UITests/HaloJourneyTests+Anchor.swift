// HaloJourneyTests+Anchor.swift: HJ-AN (anchor-parenting AN-7 writes it
// skipped, AN-8 turns it on; docs/blueprints/suiteui/features/anchor-parenting.md,
// Journey steps). On `-HaloSample three-layers` it selects Badge, drags its
// anchor mark in the viewer to the bottom edge of its box (the layer stays
// where it is, and Edit holds "Undo Set Anchor"), then keys rotation 0 at
// frame 0 and 30 at frame 24: scrubbed to 24, the layer has swung from its
// base, so the base's midpoint is where it was. Shots: `halo-anchor-*`.
import XCTest

final class HaloAnchorJourneyTests: XCTestCase {
    static let arguments = ["-HaloSample", "three-layers", "-HaloWindowSize", "1000x640"]

    /// HJ-AN: drag the anchor to the bottom edge, key a turn, and the layer swings from its base.
    @MainActor func testDragAnchorKeepsPlace() throws { throw XCTSkip("waits on AN-8") }
}
