// LibraryCropLiveDragTests.swift: a crop handle drag shown before the catalog
// takes it (#6022, the gesture contract's crop row). `cropDraft(_:dragging:dx:dy:)`
// gives the draft `dragCrop` would leave from any draft, so the loupe can chain
// a drag's steps off the catalog; `setCropDraft` takes the result at the
// release. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryCropLiveDragTests {
    @Test func chainedStepsMatchDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.dragCrop(.bottomRight, dx: -2000, dy: -1500)
        let before = try #require(catalog.cropDraft)
        var committed = catalog
        var shown = before
        for (handle, dx, dy) in [(CropHandle.inside, 300.0, 200.0), (.inside, 40, -10), (.left, 25, 0), (.top, 0, 9000)] {
            shown = try #require(catalog.cropDraft(shown, dragging: handle, dx: dx, dy: dy))
            committed.dragCrop(handle, dx: dx, dy: dy)
            // Showing a step leaves the catalog alone.
            #expect(catalog.cropDraft == before)
            #expect(committed.cropDraft == shown)
        }
        #expect(shown != before)
        catalog.setCropDraft(shown)
        #expect(catalog.cropDraft == committed.cropDraft)
        #expect(catalog.cropFrameValue == committed.cropFrameValue && catalog.cropFrameValue != nil)
    }

    @Test func noDraftNoDrag() throws {
        var catalog = cropLiveLoupe()
        var cropping = catalog
        cropping.beginCrop()
        let draft = try #require(cropping.cropDraft)
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: 1, dy: 1) == nil)
        #expect(cropping.cropDraft(draft, dragging: .inside, dx: .nan, dy: 1) == nil)
        // Outside crop mode a shown draft opens nothing.
        catalog.setCropDraft(draft)
        #expect(catalog.cropDraft == nil)
    }
}
