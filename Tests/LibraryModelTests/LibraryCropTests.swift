// LibraryCropTests.swift: crop CR-1, the catalog's crop draft on the fakes,
// and MJ6 (`walkJ6OnFakes`). Runs on Linux and macOS.
@testable import LibraryModel
import Testing

/// The shoot fixture's photo `IMG_<n>` (ids are paths).
private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

/// The shoot sorted by name on `services` (the fakes by default), in the grid.
private func shoot(_ services: LibraryServices = .fake()) -> LibraryCatalog {
    var catalog = LibraryCatalog(services: services)
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    return catalog
}

/// The shoot with `IMG_<n>` open in the loupe.
private func loupe(_ n: Int = 1, _ services: LibraryServices = .fake()) -> LibraryCatalog {
    var catalog = shoot(services)
    catalog.open(shot(n))
    return catalog
}

private func stored(_ catalog: LibraryCatalog, _ n: Int) -> CropSettings? {
    catalog.items.first { $0.id == shot(n) }?.develop.crop
}

/// A crop geometry that passes the angle through unclamped, so the catalog's own clamp shows.
private struct PassThroughCrop: CropGeometry {
    func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings {
        CropSettings(angle: angle, rect: .full, aspect: aspect)
    }
    func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                 photo: PixelSize) throws -> CropSettings { crop }
    func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings {
        CropSettings(angle: angle, rect: crop.rect, aspect: crop.aspect)
    }
    func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect {
        PixelRect(x: 0, y: 0, width: photo.width, height: photo.height)
    }
}

struct LibraryCropTests {
    @Test func inTheGridCropSaysWhyAndBeginDoesNothing() {
        var catalog = shoot()
        #expect(catalog.cropHelp == "Open a photo in the loupe to crop it.")
        catalog.beginCrop()
        #expect(catalog.cropDraft == nil)
        #expect(catalog.cropTitle == "Crop")
        #expect(catalog.cropFrameValue == nil)
        #expect(catalog.cropLoupeSettings == nil)
    }

    @Test func theServicesReasonComesFirst() {
        var services = LibraryServices.fake()
        services.unavailable["crop"] = "Crop isn't connected yet (crop)."
        var catalog = loupe(1, services)
        #expect(catalog.cropHelp == "Crop isn't connected yet (crop).")
        catalog.toggleCrop()
        #expect(catalog.cropDraft == nil)
    }

    @Test func aPhotoWithNoPixelSizeCantCrop() {
        var photos = LibraryFixtures.photos(named: "shoot")
        photos[0] = photos[0].withSize(PixelSize(width: 0, height: 0))
        var catalog = LibraryCatalog(services: .fake())
        catalog.load(photos)
        catalog.open(shot(1))
        #expect(catalog.cropHelp == "This photo has no pixel size.")
        catalog.beginCrop()
        #expect(catalog.cropDraft == nil)
    }

    @Test func beginOpensTheWholePhotoAtZero() {
        var catalog = loupe()
        #expect(catalog.cropHelp == nil)
        catalog.beginCrop()
        #expect(catalog.cropDraft == CropSettings(angle: 0, rect: .full, aspect: .original))
        #expect(catalog.cropFrameValue == "6000 × 4000 at 0, 0")
        #expect(catalog.cropCanvas == PixelSize(width: 6000, height: 4000))
        #expect(catalog.cropTitle == "Done Cropping")
        #expect(catalog.history.undo.isEmpty)
    }

    @Test func aspectDragAngleAndLevelReshapeTheDraftAndRecordNothing() {
        var catalog = loupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        #expect(catalog.cropFrameValue == "4000 × 4000 at 1000, 0")
        catalog.dragCrop(.inside, dx: 3, dy: 0)
        #expect(catalog.cropFrameValue?.hasSuffix("at 1003, 0") == true)
        catalog.setCropAngle(60)
        #expect(catalog.cropDraft?.angle == 45)
        catalog.setCropAngle(.nan)
        #expect(catalog.cropDraft?.angle == 45)
        catalog.setCropAngle(.infinity)
        #expect(catalog.cropDraft?.angle == 45)
        catalog.setCropAngle(1)
        catalog.levelCrop(by: 2.5)
        #expect(catalog.cropDraft?.angle == 3.5)
        catalog.levelCrop(by: nil)
        #expect(catalog.cropDraft?.angle == 3.5)
        #expect(catalog.history.undo.isEmpty)
    }

    @Test func theCatalogClampsTheAngleItself() {
        var services = LibraryServices.fake()
        services.crop = PassThroughCrop()
        var catalog = loupe(1, services)
        catalog.beginCrop()
        catalog.setCropAngle(60)
        #expect(catalog.cropDraft?.angle == 45)
        catalog.setCropAngle(-90)
        #expect(catalog.cropDraft?.angle == -45)
    }

    @Test func applyIsOneCropStepAndBeginReopensIt() {
        var catalog = loupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let draft = catalog.cropDraft
        catalog.toggleCrop()
        #expect(catalog.history.undo.count == 1)
        #expect(catalog.undoTitle == "Undo Crop")
        #expect(stored(catalog, 1) == draft)
        #expect(catalog.cropDraft == nil)
        #expect(catalog.cropTitle == "Crop")
        #expect(catalog.loupeItem.map(catalog.croppedSize) == PixelSize(width: 4000, height: 4000))
        catalog.beginCrop()
        #expect(catalog.cropDraft == draft)
    }

    @Test func cancelAndApplyingAnUntouchedDraftRecordNothing() {
        var catalog = loupe()
        catalog.beginCrop()
        catalog.applyCrop()
        #expect(catalog.cropDraft == nil)
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        catalog.cancelCrop()
        #expect(catalog.cropDraft == nil)
        #expect(catalog.history.undo.isEmpty)
        #expect(stored(catalog, 1) == nil)
    }

    @Test func applyDropsThePhotosThumbnail() throws {
        var catalog = shoot()
        let image = try #require(DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [0, 0, 0, 255]))
        for request in catalog.requestThumbnails(visible: [shot(1)]) { catalog.setThumbnail(image, for: request) }
        catalog.open(shot(1))
        #expect(catalog.thumbnails[shot(1)] != nil)
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        catalog.applyCrop()
        #expect(catalog.thumbnails[shot(1)] == nil)
    }

    @Test func resetWhileCroppingResetsTheDraftOnly() {
        var catalog = loupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        catalog.setCropAngle(5)
        #expect(catalog.resetCropHelp == nil)
        catalog.resetCrop()
        #expect(catalog.cropDraft == CropSettings(angle: 0, rect: .full, aspect: .original))
        #expect(catalog.history.undo.isEmpty)
    }

    @Test func resetOutsideCropIsOneResetCropStep() {
        var catalog = loupe()
        #expect(catalog.resetCropHelp == "This photo isn't cropped.")
        catalog.resetCrop()
        #expect(catalog.history.undo.isEmpty)
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        catalog.applyCrop()
        #expect(catalog.resetCropHelp == nil)
        catalog.resetCrop()
        #expect(catalog.history.undo.count == 2)
        #expect(catalog.undoTitle == "Undo Reset Crop")
        #expect(stored(catalog, 1) == nil)
    }

    /// The loupe turns the picture itself, so a straighten step asks for the same render.
    @Test func theLoupeRendersTheWholeUnturnedPhotoWhileCropping() throws {
        var catalog = loupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        let level = try #require(catalog.cropLoupeSettings)
        catalog.setCropAngle(5)
        #expect(catalog.cropDraft?.angle == 5)
        let settings = try #require(catalog.cropLoupeSettings)
        #expect(settings.crop == CropSettings(angle: 0, rect: .full, aspect: .square))
        #expect(settings == level)
        let asked = catalog.loupeRequest(longSide: 64, quality: .preview)
        let request = try #require(asked)
        #expect(request.settings == settings)
        catalog.cancelCrop()
        let plainAsked = catalog.loupeRequest(longSide: 64, quality: .preview)
        let plain = try #require(plainAsked)
        #expect(plain.settings.crop == nil)
    }

    @Test func leavingThePhotoClosesTheDraft() {
        var catalog = loupe()
        catalog.beginCrop()
        catalog.setCropAspect(.square)
        catalog.stepLoupe(by: 1)
        catalog.loupeFocusChanged()
        #expect(catalog.cropDraft == nil)
        catalog.applyCrop()
        #expect(stored(catalog, 2) == nil)
        #expect(catalog.history.undo.isEmpty)
    }

    /// MJ6: J6 steps 1-5, 7 and 9 on the fakes with the shoot fixture.
    @Test func walkJ6OnFakes() {
        var catalog = loupe()
        // 1. R opens the whole 6000 x 4000 photo.
        catalog.toggleCrop()
        #expect(catalog.cropFrameValue?.hasPrefix("6000 × 4000") == true)
        #expect(catalog.cropTitle == "Done Cropping")
        // 2. 1:1.
        catalog.setCropAspect(.square)
        #expect(catalog.cropFrameValue?.hasPrefix("4000 × 4000") == true)
        // 3. Straighten 5: the frame narrows.
        catalog.setCropAngle(5)
        #expect(catalog.cropDraft?.angle == 5)
        #expect((catalog.cropFrame?.width ?? 4000) < 4000)
        // 4. Return applies one "Crop" step; the photo is square.
        catalog.toggleCrop()
        #expect(catalog.undoTitle == "Undo Crop")
        let applied = catalog.loupeItem.map(catalog.croppedSize)
        #expect(applied.map { $0.width == $0.height } == true)
        // 5. Undo; R, a handle drag, Escape: back to 3:2 and Redo still "Redo Crop".
        catalog.undo()
        catalog.toggleCrop()
        catalog.dragCrop(.topLeft, dx: 200, dy: 200)
        catalog.cancelCrop()
        #expect(catalog.loupeItem.map(catalog.croppedSize) == PixelSize(width: 6000, height: 4000))
        #expect(catalog.redoTitle == "Redo Crop")
        // 7. R, 1:1, Right three times: "at 1003, 0".
        catalog.toggleCrop()
        catalog.setCropAspect(.square)
        for _ in 0..<3 { catalog.dragCrop(.inside, dx: 1, dy: 0) }
        #expect(catalog.cropFrameValue?.hasSuffix("at 1003, 0") == true)
        catalog.cancelCrop()
        // 9. IMG_0002 to 1:1, apply, Reset Crop: back to 3:2, "Undo Reset Crop".
        catalog.stepLoupe(by: 1)
        catalog.loupeFocusChanged()
        catalog.toggleCrop()
        catalog.setCropAspect(.square)
        catalog.toggleCrop()
        catalog.resetCrop()
        #expect(catalog.loupeItem.map(catalog.croppedSize) == PixelSize(width: 6000, height: 4000))
        #expect(catalog.undoTitle == "Undo Reset Crop")
        #expect(catalog.resetCropHelp == "This photo isn't cropped.")
    }
}
