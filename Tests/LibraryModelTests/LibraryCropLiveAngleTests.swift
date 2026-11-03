// LibraryCropLiveAngleTests.swift: a Straighten step shown before the catalog
// takes it (#6222). `cropDraft(angle:)` gives the draft `setCropAngle` would
// leave, without changing the catalog, and `cropFrame(of:)`, `cropCanvas(of:)`
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
}
