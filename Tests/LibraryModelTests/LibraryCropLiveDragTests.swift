// LibraryCropLiveDragTests.swift: a crop-frame drag shown before the catalog
// takes it (#6022). `cropDraft(_:dragging:dx:dy:)` gives the draft
// `dragCrop` would leave from any draft, without changing the catalog, so a
// drag's samples chain on the shown draft; `takeCropDraft(_:madeFrom:)` stores
// it only while the catalog still holds the draft it was made from. Runs on
// Linux and macOS.
@testable import LibraryModel
import Testing

@Suite
struct LibraryCropLiveDragTests {
    @Test func chainedDragMatchesDragCrop() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.dragCrop(.bottomRight, dx: -300, dy: -200)
        let base = try #require(catalog.cropDraft)
        let steps: [(Double, Double)] = [(40, 10), (25, -5), (0, 30)]
        var shown = base
        for (dx, dy) in steps { shown = try #require(catalog.cropDraft(shown, dragging: .inside, dx: dx, dy: dy)) }
        // Showing the steps leaves the catalog alone.
        #expect(catalog.cropDraft == base)
        var committed = catalog
        for (dx, dy) in steps { committed.dragCrop(.inside, dx: dx, dy: dy) }
        #expect(committed.cropDraft == shown && shown != base)
        catalog.takeCropDraft(shown, madeFrom: base)
        #expect(catalog.cropDraft == shown)
    }

    @Test func staleDraftIsDropped() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        catalog.dragCrop(.bottomRight, dx: -300, dy: -200)
        let base = try #require(catalog.cropDraft)
        let shown = try #require(catalog.cropDraft(base, dragging: .inside, dx: 50, dy: 50))
        catalog.setCropAspect(.square)
        let now = catalog.cropDraft
        catalog.takeCropDraft(shown, madeFrom: base)
        #expect(catalog.cropDraft == now)
        catalog.cancelCrop()
        catalog.takeCropDraft(shown, madeFrom: base)
        #expect(catalog.cropDraft == nil)
    }

    @Test func noDraftOrBadStepNoDrag() throws {
        var catalog = cropLiveLoupe()
        catalog.beginCrop()
        let draft = try #require(catalog.cropDraft)
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: .nan, dy: 0) == nil)
        catalog.cancelCrop()
        #expect(catalog.cropDraft(draft, dragging: .inside, dx: 1, dy: 1) == nil)
    }
}
