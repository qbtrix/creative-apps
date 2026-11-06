// LibraryCropLiveAngleTests.swift: a Straighten step shown before the catalog
// takes it (#6222). `cropDraft(angle:)` gives the draft `setCropAngle` would
// leave, without changing the catalog, and `cropFrame(of:)`, `cropCanvas(of:)`
// and `cropFrameValue(of:)` give that draft's frame, canvas and frame value as
// the catalog's own read once it holds the draft. A frame drag shows the same
// way: `cropDraft(_:dragging:dx:dy:)` gives what `dragCrop` would leave from any
// draft, so the loupe can chain a drag's samples before the catalog takes the
// last one. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryCropLiveAngleTests {
    @Test func draftAtAngleMatchesSetCropAngle() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let before = catalog.cropDraft
        for degrees in [7.5, -12.0, 60.0, -0.1] {
            let shown = try #require(catalog.cropDraft(angle: degrees))
            let frame = catalog.cropFrame(of: shown), canvas = catalog.cropCanvas(of: shown)
            let value = catalog.cropFrameValue(of: shown)
            // Showing a step leaves the catalog alone.
            #expect(catalog.cropDraft == before)
            var committed = catalog
            committed.setCropAngle(degrees)
            #expect(committed.cropDraft == shown)
            #expect(committed.cropFrame == frame && frame != nil)
            #expect(committed.cropCanvas == canvas && canvas != nil)
            #expect(committed.cropFrameValue == value && value != nil)
        }
        #expect(catalog.cropDraft(angle: 60)?.angle == CropSettings.angleRange.upperBound)
    }

    @Test func draggedDraftMatchesDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let base = try #require(catalog.cropDraft)
        var committed = catalog
        var shown = base
        for (handle, dx, dy) in [(CropHandle.topLeft, 300.0, 200.0), (.inside, 150, -40), (.bottomRight, -90, -60)] {
            shown = try #require(catalog.cropDraft(shown, dragging: handle, dx: dx, dy: dy))
            committed.dragCrop(handle, dx: dx, dy: dy)
            // Showing a sample leaves the catalog alone.
            #expect(catalog.cropDraft == base)
            #expect(committed.cropDraft == shown)
        }
        #expect(shown != base)
        catalog.setCropDraft(shown)
        #expect(catalog.cropDraft == committed.cropDraft)
        var closed = cropLiveLoupe()
        closed.setCropDraft(shown)
        #expect(closed.cropDraft == nil)
        #expect(catalog.cropDraft(base, dragging: .inside, dx: .nan, dy: 0) == nil)
        #expect(cropLiveLoupe().cropDraft(base, dragging: .inside, dx: 10, dy: 0) == nil)
    }

    @Test func noDraftNoAngle() {
        let catalog = cropLiveLoupe()
        #expect(catalog.cropDraft(angle: 5) == nil)
        var cropping = catalog
        cropping.beginCrop()
        #expect(cropping.cropDraft(angle: .nan) == nil)
    }
}
