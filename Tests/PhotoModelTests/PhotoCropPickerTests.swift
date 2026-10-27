// PhotoCropPickerTests.swift (orientation-crop OC-13): a CropAspectPicker pick locks Photo's crop,
// and the picker reads back its chip and orientation. An open 800 x 600 image. Linux and macOS.
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoCropPickerTests {
    private func image(width: Int = 800, height: Int = 600) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .live)
        try workspace.open(rgba8: [UInt8](repeating: 200, count: width * height * 4), width: width, height: height, name: "g.png")
        workspace.selectTool(.crop)
        return workspace
    }

    private func pick(_ aspect: SuiteKernel.CropAspect, _ orientation: CropOrientation, swap: Bool = false) -> CropPick {
        CropPick(command: swap ? CropAspectChoices.swapCommand : CropAspectChoices.aspectCommand, aspect: aspect, orientation: orientation)
    }

    /// 4:5 portrait on a landscape image: a 4:5 lock, a pending crop taller than wide, the 4:5 chip lit.
    @Test func fourFivePortraitStandsUp() throws {
        var workspace = try image()
        workspace.pickCropAspect(pick(.ratio(width: 4, height: 5), .portrait))
        #expect(workspace.cropAspect == .ratio(4, 5))
        let crop = try #require(workspace.pendingCrop)
        #expect(crop.height > crop.width && crop.height == 600)
        #expect(CropAspectChoice.chip(for: workspace.cropPickerAspect) == .fourFive && workspace.cropPickerOrientation == .portrait)
    }

    /// The same chip standing landscape locks the long side across.
    @Test func fourFiveLandscapeLiesDown() throws {
        var workspace = try image()
        workspace.pickCropAspect(pick(.ratio(width: 4, height: 5), .landscape))
        #expect(workspace.cropAspect == .ratio(5, 4) && workspace.cropPickerOrientation == .landscape)
        #expect(CropAspectChoice.chip(for: workspace.cropPickerAspect) == .fourFive)
    }

    /// The X toggle turns a ratio lock and its pending crop, as Swap did.
    @Test func toggleTurnsTheRatio() throws {
        var workspace = try image()
        workspace.pickCropAspect(pick(.ratio(width: 3, height: 2), .landscape))
        #expect(workspace.cropAspect == .ratio(3, 2) && workspace.cropPickerOrientation == .landscape)
        workspace.pickCropAspect(pick(workspace.cropPickerAspect, .portrait, swap: true))
        #expect(workspace.cropAspect == .ratio(2, 3))
        let crop = try #require(workspace.pendingCrop)
        #expect(crop.height > crop.width)
        #expect(CropAspectChoice.chip(for: workspace.cropPickerAspect) == .threeTwo && workspace.cropPickerOrientation == .portrait)
    }

    /// Original's toggle is never dead: it locks to the image's own ratio turned the other way.
    @Test func originalTurnsToTheImagesRatioSwapped() throws {
        var workspace = try image()
        workspace.pickCropAspect(pick(.original, .landscape))
        #expect(workspace.cropAspect == .original && workspace.cropPickerOrientation == .landscape)
        workspace.pickCropAspect(pick(.original, .portrait, swap: true))
        #expect(workspace.cropAspect == .ratio(3, 4) && workspace.cropPickerOrientation == .portrait)
    }

    /// Free and a square keep their shape whichever way the pick stands; Original follows the image.
    @Test func freeSquareAndOriginalReadBack() throws {
        var workspace = try image(width: 300, height: 500)
        workspace.pickCropAspect(pick(.original, .portrait))
        #expect(workspace.cropAspect == .original && workspace.cropPickerOrientation == .portrait)
        workspace.pickCropAspect(pick(.ratio(width: 1, height: 1), .portrait))
        #expect(workspace.cropAspect == .ratio(1, 1) && workspace.cropPickerAspect == .ratio(width: 1, height: 1))
        workspace.pickCropAspect(pick(.free, .portrait))
        #expect(workspace.cropAspect == .free && workspace.cropPickerAspect == .free)
    }

    /// A typed custom ratio keeps its sides; Photo's old 4:3 lock shows as Custom.
    @Test func customRatioKeepsItsSides() throws {
        var workspace = try image()
        workspace.pickCropAspect(pick(.ratio(width: 7, height: 3), .landscape))
        #expect(workspace.cropAspect == .ratio(7, 3) && CropAspectChoice.chip(for: workspace.cropPickerAspect) == .custom)
        workspace.setCropAspect(.ratio(4, 3))
        #expect(workspace.cropPickerAspect == .ratio(width: 4, height: 3) && CropAspectChoice.chip(for: workspace.cropPickerAspect) == .custom)
    }

    /// With no image a pick still records the lock and changes no crop.
    @Test func noImageMakesNoCrop() {
        var workspace = PhotoWorkspace(services: .live)
        workspace.pickCropAspect(pick(.ratio(width: 4, height: 5), .portrait))
        #expect(workspace.pendingCrop == nil)
        workspace.pickCropAspect(pick(.original, .portrait, swap: true))
        #expect(workspace.pendingCrop == nil)
    }
}
