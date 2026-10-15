// PhotoCropOptionsTextTests.swift: what the crop options say (photo-crop,
// Anatomy round 1): the one caption in every state, why Swap is off, the
// fields' numbers with no crop, their tooltips, the chips' tooltips and the
// disabled reasons, down to a field the lock or the image's edge pins and an
// Apply that would change nothing (Anatomy round 2), and journey PJ-8's steps
// on the model (CP-5). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCropOptionsTextTests {
    /// An open 800 x 600 image with the crop tool picked and nothing pending.
    private func image() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .live)
        try workspace.open(
            rgba8: [UInt8](repeating: 200, count: 800 * 600 * 4), width: 800, height: 600, name: "g.png")
        workspace.selectTool(.crop)
        return workspace
    }

    /// `setCropField(field, to: value)`'s answer (a mutating call can't sit in `#expect`).
    private func typed(_ workspace: inout PhotoWorkspace, _ field: CropField, _ value: Int) -> Bool {
        workspace.setCropField(field, to: value)
    }

    @Test func captionSaysWhatToDoThenWhatTheCropIs() throws {
        #expect(PhotoWorkspace(services: .live).cropCaption == "Open an image to crop it.")
        var workspace = try image()
        #expect(workspace.cropCaption == "Drag on the image, or pick a ratio below, to start a crop.")
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.cropCaption == "Crop 600 × 600 px, 1:1")
        workspace.cancelCrop()
        #expect(workspace.cropCaption == "Drag on the image, or type a size.")
        workspace.setCropAspect(.original)
        #expect(workspace.cropCaption == "Crop 800 × 600 px, Original")
        workspace.setCropAspect(.free)
        stroke(&workspace, .crop, from: point(10, 10), to: point(210, 110))
        #expect(workspace.cropCaption == "Crop 200 × 100 px, Free")
    }

    @Test func captionReadsASwappedRatio() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(3, 2))
        #expect(workspace.cropCaption.hasSuffix(", 3:2"))
        workspace.swapCropAspect()
        let crop = try #require(workspace.pendingCrop)
        #expect(workspace.cropCaption == "Crop \(crop.width) × \(crop.height) px, 2:3")
        #expect(crop.height > crop.width)
    }

    @Test func swapSaysWhyItCannotAct() throws {
        #expect(PhotoWorkspace(services: .live).cropSwapHelp == "Open an image to crop first.")
        var workspace = try image()
        #expect(workspace.cropSwapHelp == "Free has no fixed shape to swap.")
        workspace.setCropAspect(.original)
        #expect(workspace.cropSwapHelp == "Original keeps the image's own shape.")
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.cropSwapHelp == "A square crop is the same both ways.")
        workspace.setCropAspect(.ratio(2, 2))
        #expect(workspace.cropSwapHelp == "A square crop is the same both ways.")
        workspace.setCropAspect(.ratio(3, 2))
        #expect(workspace.cropSwapHelp == nil)
    }

    @Test func swapNamesTheChangeItMakes() throws {
        #expect(PhotoWorkspace(services: .live).cropSwapTitle == "Swap Width and Height")
        var workspace = try image()
        #expect(workspace.cropSwapTitle == "Swap Width and Height")
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.cropSwapTitle == "Swap Width and Height")
        workspace.setCropAspect(.ratio(3, 2))
        #expect(workspace.cropSwapTitle == "Swap to 2:3")
        workspace.swapCropAspect()
        #expect(workspace.cropSwapTitle == "Swap to 3:2")
    }

    @Test func theTextSaysRatioNotShape() throws {
        let workspace = try image()
        #expect(workspace.cropCaption.contains("ratio") && !workspace.cropCaption.contains("shape"))
        #expect(workspace.cropAspectGroupHelp.contains("ratio") && !workspace.cropAspectGroupHelp.contains("shape"))
        #expect(!PhotoWorkspace(services: .live).cropAspectGroupHelp.contains("shape"))
    }

    @Test func fieldsShowTheWholeImageUntilACropIsPending() throws {
        #expect(CropField.allCases.allSatisfy { PhotoWorkspace(services: .live).cropFieldDisplay($0) == 0 })
        var workspace = try image()
        #expect(workspace.cropFieldValue(.width) == nil)
        #expect(workspace.cropFieldDisplay(.x) == 0 && workspace.cropFieldDisplay(.y) == 0)
        #expect(workspace.cropFieldDisplay(.width) == 800 && workspace.cropFieldDisplay(.height) == 600)
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.cropFieldDisplay(.x) == 100 && workspace.cropFieldDisplay(.y) == 0)
        #expect(workspace.cropFieldDisplay(.width) == 600 && workspace.cropFieldDisplay(.height) == 600)
    }

    @Test func everyFieldSaysWhatItMeasures() {
        let workspace = PhotoWorkspace(services: .live)
        let helps = CropField.allCases.map { workspace.cropFieldHelp($0) }
        #expect(helps.allSatisfy { !$0.isEmpty })
        #expect(Set(helps).count == 4)
    }

    @Test func chipsSayWhatTheyLock() throws {
        let workspace = try image()
        #expect(workspace.cropAspectHelp(.original) == "The image's own proportions (4:3).")
        #expect(workspace.cropAspectHelp(.free) == "Any shape.")
        #expect(workspace.cropAspectHelp(.ratio(16, 9)) == "Width to height 16:9.")
        #expect(PhotoWorkspace(services: .live).cropAspectHelp(.original) == "The image's own proportions.")
    }

    @Test func disabledReasonsAgree() throws {
        let empty = PhotoWorkspace(services: .live)
        #expect(empty.cropFieldsUnavailableHelp == "Open an image to crop first.")
        #expect(empty.cropApplyHelp == "Open an image to crop first.")
        var workspace = try image()
        let start = "Drag on the image, or pick a ratio below, to start a crop."
        #expect(workspace.cropFieldsUnavailableHelp == start && workspace.cropApplyHelp == start)
        #expect(workspace.cropCaption == start && workspace.cropApplyHelp?.contains("pick a ratio") == true)
        #expect(CropField.allCases.allSatisfy { workspace.cropFieldUnavailableHelp($0) == start })
        #expect(workspace.cropCancelHelp == "No crop to cancel.")
        #expect(empty.cropCancelHelp == "Open an image to crop first.")
        workspace.setCropAspect(.ratio(3, 2))
        #expect(workspace.cropFieldsUnavailableHelp == nil && workspace.cropApplyHelp == nil)
        #expect(workspace.cropCancelHelp == nil)
    }

    @Test func aFieldTheLockPinsSaysWhy() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.cropFieldUnavailableHelp(.y) == "The crop already spans the image's full height.")
        #expect(workspace.cropFieldUnavailableHelp(.x) == nil)
        #expect(workspace.cropFieldUnavailableHelp(.width) == nil && workspace.cropFieldUnavailableHelp(.height) == nil)
        workspace.cancelCrop()
        #expect(workspace.cropFieldUnavailableHelp(.y) == "The crop already spans the image's full height.")
        #expect(workspace.cropFieldUnavailableHelp(.x) == nil)
    }

    @Test func aWholeImageCropPinsXAndYAndCannotApply() throws {
        var workspace = try image()
        workspace.setCropAspect(.original)
        #expect(workspace.pendingCrop == PixelRect(x: 0, y: 0, width: 800, height: 600))
        #expect(workspace.cropFieldUnavailableHelp(.x) == "The crop already spans the image's full width.")
        #expect(workspace.cropFieldUnavailableHelp(.y) == "The crop already spans the image's full height.")
        #expect(workspace.cropFieldUnavailableHelp(.width) == nil)
        #expect(!workspace.canApplyCrop)
        #expect(workspace.cropApplyHelp == "The crop covers the whole image.")
        #expect(workspace.cropCancelHelp == nil)
    }

    @Test func theChipGroupSaysWhatItLocks() throws {
        #expect(PhotoWorkspace(services: .live).cropAspectGroupHelp == "Open an image to choose a crop ratio.")
        let workspace = try image()
        #expect(
            workspace.cropAspectGroupHelp
                == "Lock the crop to a ratio, width to height. Original keeps the image's own 4:3.")
    }

    @Test func xAndYTakeZeroWidthAndHeightDoNot() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(1, 1))
        #expect(typed(&workspace, .x, 0))
        #expect(typed(&workspace, .y, 0))
        #expect(workspace.cropFieldValue(.x) == 0 && workspace.cropFieldValue(.y) == 0)
        #expect(!typed(&workspace, .width, 0))
        #expect(!typed(&workspace, .height, 0))
        #expect(workspace.cropFieldValue(.width) == 600)
    }

    /// PJ-8's steps on the model, so the journey's numbers hold on Linux: the
    /// pill reads 1:1, then 2:3 with H > W, then nothing under Free; a typed X
    /// past the image clamps; a drag back over the crop keeps it; Apply crops.
    @Test func theTypedCropJourneyReadsAsPJ8Expects() throws {
        var workspace = try image()
        workspace.setCropAspect(.ratio(1, 1))
        #expect(workspace.pendingCrop == PixelRect(x: 100, y: 0, width: 600, height: 600))
        #expect(workspace.cropAspectBadge == "1:1")
        #expect(typed(&workspace, .width, 400))
        #expect(workspace.pendingCrop == PixelRect(x: 100, y: 0, width: 400, height: 400))
        #expect(workspace.cropAspectBadge == "1:1" && workspace.canvas?.width == 800)
        workspace.setCropAspect(.ratio(3, 2))
        workspace.swapCropAspect()
        let swapped = try #require(workspace.pendingCrop)
        #expect(workspace.cropAspectBadge == "2:3" && swapped.height > swapped.width)
        workspace.setCropAspect(.free)
        #expect(workspace.cropAspectBadge == nil && workspace.pendingCrop == swapped)
        stroke(&workspace, .crop, from: point(10, 10), to: point(210, 110))
        #expect(workspace.pendingCrop == PixelRect(x: 10, y: 10, width: 200, height: 100))
        #expect(typed(&workspace, .x, 700))
        #expect(workspace.pendingCrop == PixelRect(x: 600, y: 10, width: 200, height: 100))
        stroke(&workspace, .crop, from: point(600, 10), to: point(805, 110))
        #expect(workspace.pendingCrop == PixelRect(x: 600, y: 10, width: 200, height: 100))
        workspace.applyCrop()
        #expect(workspace.canvas?.width == 200 && workspace.canvas?.height == 100)
    }
}
