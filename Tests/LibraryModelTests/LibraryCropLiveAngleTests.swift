// LibraryCropLiveAngleTests.swift: a Straighten step shown before the catalog
// takes it (#6222). `cropDraft(angle:)` gives the draft `setCropAngle` would
// leave, without changing the catalog, and `cropFrame(of:)`, `cropCanvas(of:)`
// and `cropFrameValue(of:)` give that draft's frame, canvas and frame value as
// the catalog's own read once it holds the draft. A handle drag is shown the
// same way (#6022): `cropDraft(dragging:dx:dy:from:)` gives what `dragCrop`
// would leave, from the catalog's draft or from a shown one, and both live
// reads take a shown draft as `from`. Runs on Linux and macOS.
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

    @Test func dragShownMatchesDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.free)
        let before = catalog.cropDraft
        let first = try #require(catalog.cropDraft(dragging: .topLeft, dx: 40, dy: 25))
        // Showing a step leaves the catalog alone, and the step moves the frame.
        #expect(catalog.cropDraft == before && first != before)
        // A second step from the shown draft is what two committed steps leave.
        let second = try #require(catalog.cropDraft(dragging: .topLeft, dx: 30, dy: 10, from: first))
        var committed = catalog
        committed.dragCrop(.topLeft, dx: 40, dy: 25)
        #expect(committed.cropDraft == first)
        committed.dragCrop(.topLeft, dx: 30, dy: 10)
        #expect(committed.cropDraft == second)
        // A Straighten step after a shown drag keeps the drag.
        let turned = try #require(catalog.cropDraft(angle: 5, from: second))
        committed.setCropAngle(5)
        #expect(committed.cropDraft == turned)
    }

    @Test func noDraftNoDrag() {
        let catalog = cropLiveLoupe()
        #expect(catalog.cropDraft(dragging: .inside, dx: 1, dy: 1) == nil)
        var cropping = catalog
        cropping.beginCrop()
        let shown = cropping.cropDraft
        #expect(catalog.cropDraft(dragging: .inside, dx: 1, dy: 1, from: shown) == nil)
        #expect(cropping.cropDraft(dragging: .inside, dx: .nan, dy: 1) == nil)
    }

    @Test func commitTakesOnlyAFreshDraft() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.setCropAspect(.free)
        let base = try #require(catalog.cropDraft)
        let shown = try #require(catalog.cropDraft(dragging: .right, dx: -80, dy: 0))
        var stale = catalog
        stale.setCropAspect(.square)
        let moved = stale.cropDraft
        stale.commitCropDraft(shown, from: base)
        #expect(stale.cropDraft == moved)
        catalog.commitCropDraft(shown, from: base)
        #expect(catalog.cropDraft == shown)
    }
}
