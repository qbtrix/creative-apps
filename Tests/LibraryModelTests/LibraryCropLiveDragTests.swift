// LibraryCropLiveDragTests.swift: a crop handle drag shown before the catalog
// takes it. `cropDraft(_:dragging:dx:dy:)` gives the draft `dragCrop` would
// leave from any draft (the loupe chains a drag's samples on its live one),
// without changing the catalog. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryCropLiveDragTests {
    @Test func chainedSamplesMatchDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let before = try #require(catalog.cropDraft)
        var shown = before
        var committed = catalog
        for (handle, dx, dy) in [(CropHandle.inside, 40.0, 0.0), (.inside, 25, -10), (.topLeft, 30, 30), (.right, -15, 0)] {
            shown = try #require(catalog.cropDraft(shown, dragging: handle, dx: dx, dy: dy))
            committed.dragCrop(handle, dx: dx, dy: dy)
            // Showing a sample leaves the catalog alone.
            #expect(catalog.cropDraft == before)
            #expect(committed.cropDraft == shown)
        }
        #expect(shown != before)
    }

    @Test func noDraftOrBadStepNoDrag() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        let draft = try #require(catalog.cropDraft)
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: .nan, dy: 0) == nil)
        catalog.cancelCrop()
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: 5, dy: 0) == nil)
    }
}
