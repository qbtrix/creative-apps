// LibraryValuesTests.swift: the shared Library values and the exact notice
// and catalog-file texts the window shows (spine SP-1). Runs on Linux and macOS.
import LibraryModel
import Testing

@Test func fittingScalesTheLongSideDownAndNeverEnlarges() {
    #expect(PixelSize(width: 6000, height: 4000).fitting(longSide: 1024) == PixelSize(width: 1024, height: 683))
    #expect(PixelSize(width: 4000, height: 6000).fitting(longSide: 1024) == PixelSize(width: 683, height: 1024))
    #expect(PixelSize(width: 300, height: 200).fitting(longSide: 1024) == PixelSize(width: 300, height: 200))
    #expect(PixelSize(width: 10000, height: 1).fitting(longSide: 100) == PixelSize(width: 100, height: 1))
    #expect(PixelSize(width: 600, height: 400).fitting(longSide: 0) == PixelSize(width: 1, height: 1))
    #expect(PixelSize(width: 6000, height: 4000).longSide == 6000)
}

@Test func thumbnailBucketCoversTheCellAtItsScale() {
    #expect(ThumbnailBucket.longSide(forCell: 320, scale: 2) == 1024)
    #expect(ThumbnailBucket.longSide(forCell: 80, scale: 1) == 128)
    #expect(ThumbnailBucket.longSide(forCell: 129, scale: 1) == 256)
    #expect(ThumbnailBucket.longSide(forCell: 4000, scale: 2) == 1024)
    #expect(ThumbnailBucket.longSide(forCell: 0, scale: 0) == 128)
    #expect(ThumbnailBucket.cacheBytes == 256 * 1024 * 1024)
}

@Test func displayImageRefusesAByteCountThatIsNotFourAPixel() {
    let size = PixelSize(width: 2, height: 3)
    #expect(DisplayImage(size: size, rgba8: [UInt8](repeating: 0, count: 24)) != nil)
    #expect(DisplayImage(size: size, rgba8: [UInt8](repeating: 0, count: 23)) == nil)
    #expect(DisplayImage(size: size, rgba8: [UInt8](repeating: 0, count: 25)) == nil)
    #expect(DisplayImage(size: PixelSize(width: 0, height: 0), rgba8: []) == nil)
    #expect(DisplayImage(size: PixelSize(width: Int.max, height: 2), rgba8: []) == nil)
    let image = DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [1, 2, 3, 4])
    #expect(image?.checksum.count == 16)
    #expect(image?.checksum != DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [1, 2, 3, 5])?.checksum)
}

@Test func photoFileKindMatchesExtensionsWithoutCase() {
    #expect(PhotoFileKind.kind(forFileName: "a.HEIF") == .heic)
    #expect(PhotoFileKind.kind(forFileName: "a.heic") == .heic)
    #expect(PhotoFileKind.kind(forFileName: "a.JPG") == .jpeg)
    #expect(PhotoFileKind.kind(forFileName: "a.jpeg") == .jpeg)
    #expect(PhotoFileKind.kind(forFileName: "a.Png") == .png)
    #expect(PhotoFileKind.kind(forFileName: ".jpg") == nil)
    #expect(PhotoFileKind.kind(forFileName: ".heic") == nil)
    #expect(PhotoFileKind.kind(forFileName: "a.tiff") == nil)
    #expect(PhotoFileKind.kind(forFileName: "noextension") == nil)
}

@Test func importProgressCountsFromOne() {
    #expect(ImportProgress(done: 0, total: 24).text == "Importing 1 of 24")
    #expect(ImportProgress(done: 2, total: 27).text == "Importing 3 of 27")
    #expect(ImportProgress(done: 24, total: 24).text == "Importing 24 of 24")
    #expect(ImportProgress(done: 0, total: 0).text == "Importing 1 of 1")
}

@Test func everyLibraryErrorSaysTheBlueprintText() {
    let expected: [(LibraryError, String)] = [
        (.unreadableFolder("/f"), "Library can't read /f. Check that you have access to it."),
        (.noPhotos("/f"), "No photos found in /f."),
        (.notAnImage("/f/a.txt"), "not an image file"),
        (.missingFile("/f/a.jpg"), "The file is missing: /f/a.jpg"),
        (.damagedCatalog("bad json"),
         "Library couldn't read its catalog and started a new one. The old file is catalog.json.bad."),
        (.newerCatalog(version: 3), "This catalog was made by a newer Library. Update Library to open it."),
        (.invalid("Rating must be 0 to 5."), "Rating must be 0 to 5."),
        (.renderFailed("the preview failed on purpose"), "Couldn't render this photo: the preview failed on purpose."),
        (.writeFailed(path: "/out/a.jpg", reason: "The disk is full."), "The disk is full."),
        (.cancelled, "Cancelled."),
    ]
    for (error, text) in expected {
        #expect(error.message == text)
    }
}

@Test func noticesSayExactlyWhatJourneysRead() {
    #expect(ImportNotice(folder: "/f", added: 26, failures: [FileFailure(path: "/f/b.jpg", reason: "not an image file")]).message
        == "Imported 26 photos. 1 file couldn't be imported.")
    #expect(ImportNotice(folder: "/f", alreadyKnown: 26).message == "No new photos in /f.")
    #expect(ImportNotice(folder: "/f", error: .unreadableFolder("/f")).message
        == "Library can't read /f. Check that you have access to it.")
    #expect(ExportSummary(total: 2, written: ["a", "b"]).message == "Exported 2 photos.")
    #expect(ExportSummary(total: 24, written: ["a"], cancelled: true).message == "Exported 1 of 24. Export was cancelled.")
    #expect(CatalogFileState.newer(version: 2).canSave == false && CatalogFileState.damaged.canSave)
    #expect(ThumbnailBucket.longSide(forCell: 320, scale: 2) == 1024)
    #expect(ThumbnailBucket.longSide(forCell: 80, scale: 1) == 128)
}

@Test func importNoticeCoversEveryOutcome() {
    let one = [FileFailure(path: "/f/b.jpg", reason: "not an image file")]
    let two = one + [FileFailure(path: "/f/c.jpg", reason: "not an image file")]
    #expect(ImportNotice(folder: "/f", added: 1).message == "Imported 1 photo.")
    #expect(ImportNotice(folder: "/f", added: 3, failures: two).message == "Imported 3 photos. 2 files couldn't be imported.")
    #expect(ImportNotice(folder: "/f").message == "No new photos in /f.")
    #expect(ImportNotice(folder: "/f", failures: one).message == "1 file couldn't be imported.")
    #expect(ImportNotice(folder: "/f", failures: two).message == "2 files couldn't be imported.")
    #expect(ImportNotice(folder: "/f", error: .noPhotos("/f")).message == "No photos found in /f.")
    #expect(ImportNotice(folder: "/f", failures: one).isError)
    #expect(ImportNotice(folder: "/f", error: .noPhotos("/f")).isError)
    #expect(ImportNotice(folder: "/f", added: 1, failures: one).isError == false)
    #expect(ImportNotice(folder: "/f").isError == false)
}

@Test func exportSummaryCoversEveryOutcome() {
    let failure = FileFailure(path: "/out/a.jpg", reason: "The disk is full.")
    #expect(ExportSummary(total: 1, written: ["a"]).message == "Exported 1 photo.")
    #expect(ExportSummary(total: 0, written: []).message == "Exported 0 photos.")
    #expect(ExportSummary(total: 2, written: ["b"], failures: [failure], failedIDs: ["a"]).message
        == "1 photo couldn't be exported.")
    #expect(ExportSummary(total: 3, written: ["c"], failures: [failure, failure], failedIDs: ["a", "b"]).message
        == "2 photos couldn't be exported.")
    #expect(ExportSummary(total: 3, written: [], failures: [failure], cancelled: true).message
        == "Exported 0 of 3. Export was cancelled.")
}

@Test func catalogFileStateTextsAndSaving() {
    #expect(CatalogFileState.loading.message == nil)
    #expect(CatalogFileState.ready.message == nil)
    #expect(CatalogFileState.damaged.message
        == "Library couldn't read its catalog and started a new one. The old file is catalog.json.bad.")
    #expect(CatalogFileState.newer(version: 2).message
        == "This catalog was made by a newer Library. Update Library to open it.")
    #expect(CatalogFileState.ready.canSave)
    #expect(CatalogFileState.damaged.canSave)
    #expect(CatalogFileState.loading.canSave == false)
    #expect(CatalogFileState.newer(version: 2).canSave == false)
}
