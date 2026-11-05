// LibraryCropLiveAngleTests.swift: a Straighten step (#6222) or a crop frame
// drag step (#6022) shown before the catalog takes it. `cropDraft(angle:)`
// gives the draft `setCropAngle` would leave and `cropDraft(_:dragging:dx:dy:)`
// the draft `dragCrop` would leave, without changing the catalog;
// `takeCropDraft` commits a shown draft. `cropFrame(of:)`, `cropCanvas(of:)`
// and `cropFrameValue(of:)` give that draft's frame, canvas and frame value as
// the catalog's own read once it holds the draft. Runs on Linux and macOS.
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

    @Test func noDraftNoAngle() {
        let catalog = cropLiveLoupe()
        #expect(catalog.cropDraft(angle: 5) == nil)
        var cropping = catalog
        cropping.beginCrop()
        #expect(cropping.cropDraft(angle: .nan) == nil)
    }

    @Test func draggedDraftMatchesDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let before = try #require(catalog.cropDraft)
        var committed = catalog
        var shown = before
        for (handle, dx, dy) in [(CropHandle.bottomRight, -300.0, -200.0), (.inside, 120, 60), (.inside, 9000, 0), (.topLeft, 40, 25)] {
            shown = try #require(catalog.cropDraft(shown, dragging: handle, dx: dx, dy: dy))
            committed.dragCrop(handle, dx: dx, dy: dy)
            #expect(committed.cropDraft == shown)
        }
        // Showing the steps leaves the catalog alone; taking the last one lands where the drags did.
        #expect(catalog.cropDraft == before && shown != before)
        catalog.takeCropDraft(shown)
        #expect(catalog.cropDraft == committed.cropDraft)
        #expect(catalog.cropFrameValue == committed.cropFrameValue && catalog.cropFrameValue != nil)
    }

    @Test func noDraftNoDrag() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        let draft = try #require(catalog.cropDraft)
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: .nan, dy: 0) == nil)
        catalog.cancelCrop()
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: 10, dy: 0) == nil)
        catalog.takeCropDraft(draft)
        #expect(catalog.cropDraft == nil)
    }
}
