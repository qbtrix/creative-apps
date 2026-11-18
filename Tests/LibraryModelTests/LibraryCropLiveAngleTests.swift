// LibraryCropLiveAngleTests.swift: a Straighten step shown before the catalog
// takes it (#6222). `cropDraft(angle:)` gives the draft `setCropAngle` would
// leave, without changing the catalog, and `cropFrame(of:)`, `cropCanvas(of:)`
// and `cropFrameValue(of:)` give that draft's frame, canvas and frame value as
// the catalog's own read once it holds the draft. A handle drag shows the
// same way: `cropDraft(_:dragging:dx:dy:)` chains samples off the catalog and
// `takeCropDraft(_:over:)` lands them, so the samples taken together equal
// `dragCrop` per sample, and a stale draft is dropped. Runs on Linux and macOS.
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

    @Test func liveDragEqualsDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        let base = try #require(catalog.cropDraft)
        var stepped = catalog, shown = base
        for (dx, dy) in [(40.0, 20.0), (35.5, -7.0), (12.0, 30.0)] {
            stepped.dragCrop(.topLeft, dx: dx, dy: dy)
            shown = try #require(catalog.cropDraft(shown, dragging: .topLeft, dx: dx, dy: dy))
        }
        // Showing the samples leaves the catalog alone; taking them equals dragging each.
        #expect(catalog.cropDraft == base && shown != base)
        catalog.takeCropDraft(shown, over: base)
        #expect(catalog.cropDraft == stepped.cropDraft)
        #expect(catalog.history.undo.isEmpty)
        // A draft made from an older base is dropped.
        catalog.takeCropDraft(base, over: base)
        #expect(catalog.cropDraft == stepped.cropDraft)
        #expect(catalog.cropDraft(base, dragging: .inside, dx: .nan, dy: 0) == nil)
    }
}
