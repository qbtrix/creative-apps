// LibraryCropLiveDragTests.swift: a crop handle drag shown before the catalog
// takes it. `cropDraft(dragging:dx:dy:from:)` gives the draft `dragCrop`
// would leave, from any draft the loupe is showing, without changing the
// catalog, and `setCropDraft` takes the shown draft once the drag pauses.
// Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryCropLiveDragTests {
    @Test func liveStepsMatchDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let before = catalog.cropDraft
        let base = try #require(before)
        let one = try #require(catalog.cropDraft(dragging: .bottomRight, dx: -900, dy: -900, from: base))
        let two = try #require(catalog.cropDraft(dragging: .inside, dx: 300, dy: 200, from: one))
        // Showing steps leaves the catalog alone.
        #expect(catalog.cropDraft == before)
        var dragged = catalog
        dragged.dragCrop(.bottomRight, dx: -900, dy: -900)
        dragged.dragCrop(.inside, dx: 300, dy: 200)
        #expect(dragged.cropDraft == two && two != base)
        catalog.setCropDraft(two)
        #expect(catalog.cropDraft == two)
    }

    @Test func noDraftNoDrag() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        let draft = try #require(catalog.cropDraft)
        #expect(catalog.cropDraft(dragging: .inside, dx: .nan, dy: 0, from: draft) == nil)
        catalog.cancelCrop()
        #expect(catalog.cropDraft(dragging: .inside, dx: 10, dy: 0, from: draft) == nil)
        // Outside crop mode there is no draft to set.
        catalog.setCropDraft(draft)
        #expect(catalog.cropDraft == nil)
    }
}
