// PhotoJourneyTests+Text.swift: PJ-TX, a title over a photo (text-layers
// TX-2; docs/blueprints/photo/features/text-layers.md, Journey steps; RJ-P02).
// Written now and skipped: the Type tool arrives in TX-3, the inspector's
// style row in TX-4 and the layout in TX-5, and TX-7 writes the steps below
// in place of the skip, on the shared test photo written as beach.png.
import XCTest

final class PhotoTextJourneyTests: XCTestCase {
    /// PJ-TX:
    /// 1. T picks the Type tool; a click on the sky, SUMMER SALE and Esc leave one text layer above the photo.
    /// 2. The inspector's style row: a heavy weight, size 120 and Center redraw it; Undo steps back one at a time.
    /// 3. Save, close, reopen: the layer is still text; a double-click on it changes SALE to DEALS.
    @MainActor func testTitleOverPhoto() throws {
        throw XCTSkip("waits on TX-7")
    }
}
