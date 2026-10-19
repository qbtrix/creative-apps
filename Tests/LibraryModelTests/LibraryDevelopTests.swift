// LibraryDevelopTests.swift: develop DV-2 writes every check of the Develop
// tab's edits against LibraryDevelop.swift's signatures, each disabled until
// the task that fills it: DV-3 the slider, curve and levels edits, the drag's
// end, the resets and the helps; DV-4 copy, paste, sync, the histogram
// helpers and MJ2, the develop edits walk. Runs on Linux and macOS.
import CoreColor
import CoreRaster
import Foundation
@testable import LibraryModel
import Testing

/// The shoot fixture's photo `IMG_<n>` (ids are paths).
private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

private let cropped = CropSettings(angle: 3, rect: UnitRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5), aspect: .free)

/// The shoot sorted by name on the fakes, IMG_0002 cropped, in the grid.
private func shoot() -> LibraryCatalog {
    var photos = LibraryFixtures.photos(named: "shoot")
    if photos.indices.contains(1) { photos[1].develop = photos[1].develop.setting(crop: cropped) }
    var catalog = LibraryCatalog(services: .fake())
    catalog.load(photos)
    catalog.setSort(.name)
    return catalog
}

private func develop(_ catalog: LibraryCatalog, _ n: Int) -> DevelopSettings? {
    catalog.items.first { $0.id == shot(n) }?.develop
}

private func point(_ x: Double, _ y: Double) -> DevelopCurvePoint { DevelopCurvePoint(x: x, y: y) }

/// Holds a thumbnail for each of `ids`.
private func holdThumbnails(_ catalog: inout LibraryCatalog, _ ids: [String]) throws {
    let image = try #require(DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [0, 0, 0, 255]))
    for request in catalog.requestThumbnails(visible: ids) { catalog.setThumbnail(image, for: request) }
}

/// A loupe render on IMG_0001 with `histogram`.
private func showHistogram(_ catalog: inout LibraryCatalog, _ histogram: HistogramBins) throws {
    let asked = catalog.loupeRequest(longSide: 64, quality: .full)
    let request = try #require(asked)
    let image = try #require(DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [0, 0, 0, 255]))
    catalog.showLoupeRender(RenderedPhoto(image: image, histogram: histogram, quality: .full), token: request.token)
}

struct LibraryDevelopTests {
    @Test func setDevelopActsOnTheLoupePhotoElseTheSelection() {
        var catalog = shoot()
        catalog.select([shot(3), shot(4)])
        catalog.setDevelop(.exposure, to: 1, coalesceKey: nil)
        #expect(develop(catalog, 3)?.exposure == 1 && develop(catalog, 4)?.exposure == 1)
        catalog.open(shot(5))
        catalog.setDevelop(.contrast, to: 13, coalesceKey: nil)
        #expect(develop(catalog, 5)?.contrast == 13 && develop(catalog, 3)?.contrast == 0)
        #expect(catalog.developTargets == [shot(5)])
    }

    @Test func aDragIsOneStepAndDropsThumbnailsOnRelease() throws {
        var catalog = shoot()
        catalog.select([shot(1)])
        try holdThumbnails(&catalog, [shot(1)])
        let before = catalog.history.undo.count
        for i in 1...20 { catalog.setDevelop(.exposure, to: Double(i) / 10, coalesceKey: "develop-exposure") }
        #expect(catalog.thumbnails[shot(1)] != nil)  // kept during the drag
        #expect(catalog.endDevelopDrag() == [shot(1)])
        #expect(catalog.thumbnails[shot(1)] == nil)
        #expect(catalog.history.undo.count == before + 1 && catalog.undoTitle == "Undo Exposure")
        catalog.setDevelop(.exposure, to: 3, coalesceKey: "develop-exposure")
        catalog.endDevelopDrag()
        #expect(catalog.history.undo.count == before + 2)
        catalog.undo()
        catalog.undo()
        #expect(develop(catalog, 1)?.exposure == 0)
    }

    @Test func resetsTouchTheirFieldsAndKeepTheCrop() throws {
        var catalog = shoot()
        catalog.select([shot(2)])
        let curve = try #require(ToneCurve(points: [point(0, 0), point(0.5, 0.7), point(1, 1)]))
        catalog.setDevelop(.contrast, to: 20, coalesceKey: nil)
        catalog.setDevelop(.temperature, to: 10, coalesceKey: nil)
        catalog.setCurve(curve.points, coalesceKey: nil)
        catalog.setLevels(.gamma, to: 1.2, coalesceKey: nil)
        #expect(catalog.resetDevelop(.tone) == [shot(2)])
        #expect(catalog.undoTitle == "Undo Reset Tone")
        #expect(develop(catalog, 2)?.contrast == 0 && develop(catalog, 2)?.temperature == 10)
        #expect(develop(catalog, 2)?.crop == cropped)
        catalog.setDevelop(.contrast, to: 5, coalesceKey: nil)
        catalog.resetDevelop(.contrast)
        #expect(catalog.undoTitle == "Undo Reset Contrast")
        catalog.resetDevelop(nil as DevelopGroup?)
        #expect(catalog.undoTitle == "Undo Reset Develop")
        #expect(develop(catalog, 2)?.isAdjustmentNeutral == true && develop(catalog, 2)?.crop == cropped)
    }

    @Test func curveAndLevelsEditsAndResets() throws {
        var catalog = shoot()
        catalog.select([shot(1)])
        let steps = catalog.history.undo.count
        catalog.setCurve([point(0.4, 0.4)], coalesceKey: nil)
        #expect(catalog.history.undo.count == steps)
        catalog.setCurve([point(0, 0), point(0.5, 0.7), point(1, 1)], coalesceKey: nil)
        #expect(catalog.undoTitle == "Undo Curve")
        #expect(catalog.developCurve?.shared?.isIdentity == false)
        catalog.setLevels(.inWhite, to: 0.5, coalesceKey: nil)
        catalog.setLevels(.inBlack, to: 0.9, coalesceKey: nil)
        #expect(develop(catalog, 1)?.levels.inBlack == 0.5 - DevelopLevels.pointGap)
        #expect(catalog.undoTitle == "Undo Levels")
        catalog.resetCurve()
        #expect(catalog.undoTitle == "Undo Reset Curve" && develop(catalog, 1)?.curve == .identity)
        catalog.resetLevels()
        #expect(catalog.undoTitle == "Undo Reset Levels" && develop(catalog, 1)?.levels == .neutral)
    }

    @Test func helpsAndMixedValues() {
        var catalog = shoot()
        #expect(catalog.developTargets.isEmpty)
        #expect(catalog.developHelp == "Select a photo to develop it.")
        let steps = catalog.history.undo.count
        catalog.setDevelop(.exposure, to: 1, coalesceKey: nil)
        #expect(catalog.history.undo.count == steps && catalog.developValue(.exposure) == nil)
        // The fakes render every slider.
        #expect(catalog.sliderHelp(.vibrance) == nil)
        catalog.select([shot(3)])
        catalog.setDevelop(.exposure, to: 1, coalesceKey: nil)
        catalog.select([shot(1), shot(2), shot(3)])
        #expect(catalog.developHelp == nil)
        #expect(catalog.developValue(.exposure) == .mixed)
        #expect(catalog.developValue(.contrast) == .value(0))
        #expect(catalog.developLevels == .value(.neutral))
        #expect(catalog.developCurve == .value(.identity))
    }

    @Test func liveSliderHelpIsTheRenderersWaitingReason() {
        let live = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
        var catalog = LibraryCatalog(services: live)
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.select([shot(1)])
        #expect(catalog.sliderHelp(.vibrance) == LiveDevelop.waiting[.vibrance])
        #expect(catalog.sliderHelp(.exposure) == LiveDevelop.waiting[.exposure])
        let steps = catalog.history.undo.count
        catalog.setDevelop(.vibrance, to: 20, coalesceKey: nil)
        // Refused while the renderer waits on it (DV-12 empties `waiting`).
        let refused = LiveDevelop.waiting[.vibrance] != nil
        #expect(catalog.history.undo.count == (refused ? steps : steps + 1))
        #expect(develop(catalog, 1)?.vibrance == (refused ? 0 : 20))
    }

    @Test func aResetEndsAnOpenDragAndNamesNothingWhenNeutral() throws {
        var catalog = shoot()
        catalog.select([shot(1), shot(3)])
        try holdThumbnails(&catalog, [shot(1), shot(3)])
        let steps = catalog.history.undo.count
        #expect(catalog.resetDevelop(nil as DevelopGroup?).isEmpty && catalog.history.undo.count == steps)
        catalog.setDevelop(.exposure, to: 1, coalesceKey: "develop-exposure")
        #expect(catalog.thumbnails[shot(3)] != nil)
        #expect(catalog.resetDevelop(.exposure) == [shot(1), shot(3)])
        #expect(catalog.history.undo.count == steps + 2 && catalog.thumbnails[shot(3)] == nil)
        catalog.setDevelop(.exposure, to: 2, coalesceKey: "develop-exposure")
        #expect(catalog.history.undo.count == steps + 3)
        catalog.endDevelopDrag()
        try holdThumbnails(&catalog, [shot(1), shot(3)])
        catalog.resetDevelop(.tone)
        #expect(catalog.thumbnails[shot(1)] == nil && catalog.thumbnails[shot(3)] == nil)
    }

    @Test(.disabled("waits on DV-4")) func pasteIsOneStepKeepingEachCrop() {
        var catalog = shoot()
        #expect(!catalog.canPasteSettings)
        catalog.open(shot(1))
        catalog.setDevelop(.exposure, to: 1, coalesceKey: nil)
        catalog.copySettings()
        catalog.showGrid()
        catalog.select([shot(2), shot(3), shot(4)])
        #expect(catalog.canPasteSettings)
        let steps = catalog.history.undo.count
        #expect(catalog.pasteSettings() == [shot(2), shot(3), shot(4)])
        #expect(catalog.history.undo.count == steps + 1 && catalog.undoTitle == "Undo Paste Settings")
        #expect((2...4).allSatisfy { develop(catalog, $0)?.exposure == 1 })
        #expect(develop(catalog, 2)?.crop == cropped && develop(catalog, 3)?.crop == nil)
        catalog.undo()
        #expect((2...4).allSatisfy { develop(catalog, $0)?.exposure == 0 })
    }

    @Test(.disabled("waits on DV-4")) func copyNeedsOnePhotoAndSummarises() throws {
        var catalog = shoot()
        catalog.select([shot(1), shot(2)])
        catalog.copySettings()
        #expect(catalog.copiedSettings == nil && catalog.copiedSummary == nil)
        catalog.select([shot(1)])
        catalog.setDevelop(.exposure, to: 1, coalesceKey: nil)
        catalog.setDevelop(.contrast, to: 13, coalesceKey: nil)
        catalog.setCurve([point(0, 0), point(0.5, 0.7), point(1, 1)], coalesceKey: nil)
        catalog.copySettings()
        #expect(catalog.copiedSummary == "Exposure +1.00, Contrast 13, Curve")
    }

    @Test(.disabled("waits on DV-4")) func syncTakesTheFirstSelectedInTheOrder() {
        var catalog = shoot()
        catalog.select([shot(4)])
        #expect(catalog.syncSource == nil)
        catalog.select([shot(4), shot(2)])
        #expect(catalog.syncSource?.id == shot(2) && catalog.syncTitle == "Sync from IMG_0002")
        catalog.open(shot(2))
        #expect(catalog.syncSource == nil)
        catalog.showGrid()
        catalog.select([shot(2)])
        catalog.setDevelop(.shadows, to: 30, coalesceKey: nil)
        catalog.select([shot(4), shot(2)])
        let steps = catalog.history.undo.count
        #expect(catalog.syncSettings() == [shot(4)])
        #expect(catalog.history.undo.count == steps + 1 && catalog.undoTitle == "Undo Sync Settings")
        #expect(develop(catalog, 4)?.shadows == 30 && develop(catalog, 2)?.crop == cropped)
    }

    @Test(.disabled("waits on DV-4")) func histogramHelpers() throws {
        var catalog = shoot()
        catalog.open(shot(1))
        var red = [Int](repeating: 0, count: HistogramBins.binCount), green = red, blue = red
        red[255] = 4; green[255] = 2; blue[0] = 1
        try showHistogram(&catalog, HistogramBins(red: red, green: green, blue: blue,
                                                  shadowClipped: 0, highlightClipped: 6))
        #expect(catalog.histogramClips == ["Highlights clipped"])
        #expect(catalog.curveHistogram.count == HistogramBins.binCount)
        #expect(catalog.curveHistogram.max() == 1 && catalog.curveHistogram.first == 1.0 / 6)
        #expect(catalog.developError == nil)
    }

    @Test(.disabled("waits on DV-4")) func testDevelopEditsWalk() throws {
        var catalog = shoot()
        catalog.open(shot(1))
        try holdThumbnails(&catalog, [shot(1)])
        let steps = catalog.history.undo.count
        for i in 1...20 { catalog.setDevelop(.exposure, to: Double(i) / 20, coalesceKey: "develop-exposure") }
        catalog.endDevelopDrag()
        #expect(catalog.history.undo.count == steps + 1 && catalog.undoTitle == "Undo Exposure")
        #expect(catalog.thumbnails[shot(1)] == nil)
        catalog.copySettings()
        catalog.showGrid()
        catalog.select([shot(2), shot(3), shot(4)])
        catalog.pasteSettings()
        #expect(catalog.history.undo.count == steps + 2 && develop(catalog, 2)?.crop == cropped)
        catalog.undo()
        #expect((2...4).allSatisfy { develop(catalog, $0)?.isAdjustmentNeutral == true })
        catalog.select(Set((1...6).map(shot)))
        catalog.syncSettings()
        #expect(catalog.undoTitle == "Undo Sync Settings")
        catalog.select([shot(1)])
        catalog.setDevelop(.temperature, to: 10, coalesceKey: nil)
        catalog.resetDevelop(.tone)
        #expect(catalog.undoTitle == "Undo Reset Tone")
        #expect(develop(catalog, 1)?.exposure == 0 && develop(catalog, 1)?.temperature == 10)
    }
}
