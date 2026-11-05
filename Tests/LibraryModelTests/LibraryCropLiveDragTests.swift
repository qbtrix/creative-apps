// LibraryCropLiveDragTests.swift: a crop handle drag shown before the catalog
// takes it (#6022). `cropDraft(dragging:dx:dy:from:)` gives the draft
// `dragCrop` would leave on a shown draft, without changing the catalog, and
// `setCropDraft` hands the catalog the draft the loupe showed. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryCropLiveDragTests {
    @Test func liveDragMatchesDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.dragCrop(.bottomRight, dx: -2000, dy: -1500)  // room to move right and down
        let before = catalog.cropDraft
        var committed = catalog
        var shown = try #require(catalog.cropDraft)
        for (handle, dx, dy) in [(CropHandle.inside, 40.0, 20.0), (.inside, 300, 100), (.left, 25, 0), (.inside, -10, 5)] {
            shown = try #require(catalog.cropDraft(dragging: handle, dx: dx, dy: dy, from: shown))
            committed.dragCrop(handle, dx: dx, dy: dy)
        }
        // Showing the samples leaves the catalog alone; they add up to what dragCrop leaves.
        #expect(catalog.cropDraft == before)
        #expect(shown == committed.cropDraft && shown != before)
        catalog.setCropDraft(shown)
        #expect(catalog.cropFrame == committed.cropFrame && catalog.cropFrame != nil)
    }

    @Test func angleFromAShownDraft() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.dragCrop(.bottomRight, dx: -2000, dy: -1500)
        let dragged = try #require(catalog.cropDraft(dragging: .inside, dx: 300, dy: 100))
        var committed = catalog
        committed.setCropDraft(dragged)
        committed.setCropAngle(4)
        #expect(catalog.cropDraft(angle: 4, from: dragged) == committed.cropDraft)
    }

    @Test func noDraftNoDrag() {
        var catalog = cropLiveLoupe()
        #expect(catalog.cropDraft(dragging: .inside, dx: 5, dy: 5) == nil)
        let stray = CropSettings(angle: 3, rect: .full, aspect: .original)
        catalog.setCropDraft(stray)
        #expect(catalog.cropDraft == nil)
        catalog.beginCrop()
        #expect(catalog.cropDraft(dragging: .inside, dx: .nan, dy: 0) == nil)
        #expect(catalog.cropDraft(dragging: .inside, dx: 5, dy: 5, from: stray) != nil)
    }
}
