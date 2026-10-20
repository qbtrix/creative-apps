// PhotoExportPackTests.swift: Photo's export on the suite's export options
// (export-pack, MJ-PX): exact pixels on a cropped image, a refused shape, the
// long edge, and the agent's JSON options giving the sheet's pixels. Written by
// PX-1 against the stubs in PhotoExport+Kernel.swift; PX-3 turns it on.
// `PhotoExportStubTests` runs now: what the stubs already do. Linux-safe.
import PhotoModel
import SuiteKernel
import Testing

@Suite(.disabled("waits on PX-3")) struct PhotoExportPackTests {
    /// A 3:2 image cut to 4:5 in the middle: 1200 × 800 to 640 × 800.
    private func croppedToFourByFive() throws -> PhotoWorkspace {
        var workspace = try whiteImage(1200, 800)
        stroke(&workspace, .crop, from: point(280, 0), to: point(920, 800))
        workspace.applyCrop()
        return workspace
    }

    @Test func aFourByFiveCropAtPixelsWritesExactlyThatSize() throws {
        let workspace = try croppedToFourByFive()
        let options = SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350), quality: 0.85)
        let image = try workspace.exportPixels(options)
        #expect((image.width, image.height) == (1080, 1350))
    }

    @Test func aThreeByTwoImageAtFourByFivePixelsIsRefused() throws {
        let workspace = try whiteImage(1200, 800)
        let options = SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350))
        #expect(throws: ExportOptionRefusal.self) { try workspace.exportPixels(options) }
    }

    @Test func theLongEdgeKeepsTheShape() throws {
        let workspace = try whiteImage(6000, 4000)
        let image = try workspace.exportPixels(SuiteExportOptions(format: "heic", size: .longEdge(2048)))
        #expect((image.width, image.height) == (2048, 1365))
    }

    @Test func theAgentsJSONOptionsGiveTheSheetsPixels() throws {
        let workspace = try croppedToFourByFive()
        let json = JSONValue.object([
            "format": .string("jpeg"), "size": .object(["pixels": .array([.number(1080), .number(1350)])]),
            "quality": .number(0.85),
        ])
        let fromJSON = try SuiteExportOptions(json: json, defaults: workspace.exportOptionsDefault())
        let fromSheet = SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350), quality: 0.85)
        #expect(fromJSON == fromSheet)
        #expect(try workspace.exportPixels(fromJSON) == workspace.exportPixels(fromSheet))
    }
}

/// What the PX-1 stubs already do, enabled now: the four stills, the default
/// options, and the flattened image per format at the image's own size.
@Suite struct PhotoExportStubTests {
    /// A 2 x 1 image: one opaque red pixel, one fully transparent pixel.
    private func halfTransparent() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [255, 0, 0, 255, 0, 0, 0, 0], width: 2, height: 1, name: "half.png")
        return workspace
    }

    @Test func theFormatsAreTheSuitesFourStills() {
        #expect(PhotoWorkspace.exportFormats.map(\.id) == ["png", "jpeg", "heic", "tiff"])
        #expect(PhotoWorkspace.exportFormats.allSatisfy { ExportFormats.spec($0.id) == $0 })
    }

    @Test func aFreshExportIsPNGAtTheImagesOwnSize() throws {
        let options = try whiteImage().exportOptionsDefault()
        #expect(options == SuiteExportOptions(format: "png", size: .scale(1), quality: 0.9))
        #expect(PhotoWorkspace.exportFormats.contains { $0.id == options.format })
    }

    @Test(arguments: ["png", "heic", "tiff"])
    func formatsThatKeepAlphaGiveTheFlatImageAsIs(_ format: String) throws {
        let workspace = try halfTransparent()
        let image = try workspace.exportPixels(SuiteExportOptions(format: format))
        #expect(image == (try workspace.exportPixels(as: .png)))
        #expect((image.width, image.height) == (2, 1))
        #expect(image.rgba8.last == 0)
    }

    @Test func jpegGivesTheImageOnOpaqueWhite() throws {
        let workspace = try halfTransparent()
        let image = try workspace.exportPixels(SuiteExportOptions(format: "jpeg"))
        #expect(image == (try workspace.exportPixels(as: .jpeg)))
        #expect(Array(image.rgba8.suffix(4)) == [255, 255, 255, 255])
    }

    @Test func exportWithNoImageOpenThrows() {
        #expect(throws: (any Error).self) { try PhotoWorkspace().exportPixels(SuiteExportOptions()) }
    }
}
