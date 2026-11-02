// LibraryCropRenderTests.swift: crop CR-3, the cropped render's checks
// (slice CR-b, QB-LIB-V4) and MJ6L (`walkJ6Live`), written first and
// enabled by CR-4, which makes `LiveDevelop.render` turn and crop after tone.
// They call `LiveDevelop().render(_:settings:)` and the live services' crop
// geometry (LibraryLiveCropTests' helpers), so CR-4 keeps both seams.
// Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import Testing

/// Every pixel's alpha within 1e-4 of 1.
func cropEveryPixelIsOpaque(_ buffer: PixelBuffer) throws -> Bool {
    for y in 0..<buffer.height {
        for x in 0..<buffer.width where abs(try buffer.pixel(x: x, y: y).a - 1) > 1e-4 { return false }
    }
    return true
}

/// The largest difference of any component of two same-size buffers.
func cropLargestDifference(_ a: PixelBuffer, _ b: PixelBuffer) throws -> Float {
    var most: Float = 0
    for y in 0..<a.height {
        for x in 0..<a.width {
            let p = try a.pixel(x: x, y: y), q = try b.pixel(x: x, y: y)
            most = max(most, abs(p.r - q.r), abs(p.g - q.g), abs(p.b - q.b), abs(p.a - q.a))
        }
    }
    return most
}

@Suite
struct LibraryCropRenderTests {
    let develop = LiveDevelop()
    let gradientSize = PixelSize(width: 600, height: 400)

    @Test func neutralSettingsWithNoCropReturnTheBufferUnchanged() throws {
        let gradient = try developGradient(width: 600, height: 400)
        #expect(try develop.render(gradient, settings: .neutral) == gradient)
    }

    @Test func halfTheWidthRenders300PxOfTheSamePixels() throws {
        let gradient = try developGradient(width: 600, height: 400)
        let half = CropSettings(angle: 0, rect: UnitRect(x: 0.25, y: 0, width: 0.5, height: 1), aspect: .free)
        let out = try develop.render(gradient, settings: DevelopSettings.neutral.setting(crop: half))
        let byHand = try gradient.cropped(x: 150, y: 0, width: 300, height: 400)
        #expect(out.width == 300 && out.height == 400)
        #expect(out == byHand)
    }

    @Test func theRenderIsTheFramesSize() throws {
        let gradient = try developGradient(width: 600, height: 400)
        let crop = cropLiveGeometry()
        for (aspect, angle) in [(CropAspect.square, 0.0), (.square, 5), (.threeTwo, -12), (.free, 30)] {
            let settings = try crop.initial(aspect: aspect, angle: angle, photo: gradientSize)
            let frame = try crop.frame(settings, photo: gradientSize)
            let out = try develop.render(gradient, settings: DevelopSettings.neutral.setting(crop: settings))
            #expect(out.width == frame.width && out.height == frame.height, "\(aspect) at \(angle)°")
        }
    }

    @Test func aSquareAtTenDegreesIsOpaqueEverywhere() throws {
        let gradient = try developGradient(width: 600, height: 400)
        let square = try cropLiveGeometry().initial(aspect: .square, angle: 10, photo: gradientSize)
        let out = try develop.render(gradient, settings: DevelopSettings.neutral.setting(crop: square))
        #expect(abs(out.width - out.height) <= 1)
        #expect(out.width < 400)
        #expect(try cropEveryPixelIsOpaque(out))
    }

    @Test func toneAndCropBothApply() throws {
        let gradient = try developGradient(width: 600, height: 400)
        let half = CropSettings(angle: 0, rect: UnitRect(x: 0.25, y: 0, width: 0.5, height: 1), aspect: .free)
        let toned = DevelopSettings.neutral.setting(.exposure, to: 0.5)
        let out = try develop.render(gradient, settings: toned.setting(crop: half))
        let byHand = try develop.render(gradient, settings: toned).cropped(x: 150, y: 0, width: 300, height: 400)
        #expect(out == byHand)
    }

    /// #3619: the turned frame samples only its own pixels, in bands, and
    /// still gives what turning the whole photo and cutting the frame gives.
    @Test func aTurnedCropMatchesTurningTheWholePhotoThenCutting() throws {
        let gradient = try developGradient(width: 600, height: 400)
        let crop = cropLiveGeometry()
        for (aspect, angle) in [(CropAspect.square, 5.0), (.threeTwo, -12), (.free, 30), (.square, 44.9)] {
            var settings = try crop.initial(aspect: aspect, angle: angle, photo: gradientSize)
            // Off center, so a dropped frame origin shows.
            settings = try crop.dragged(settings, handle: .topLeft, dx: 40, dy: 25, photo: gradientSize)
            let f = try crop.frame(settings, photo: gradientSize)
            let out = try develop.render(gradient, settings: DevelopSettings.neutral.setting(crop: settings))
            let byHand = try gradient.rotated(degrees: angle, filter: .lanczos3)
                .cropped(x: f.x, y: f.y, width: f.width, height: f.height)
            #expect(out.width == byHand.width && out.height == byHand.height, "\(aspect) at \(angle)°")
            #expect(try cropLargestDifference(out, byHand) <= 1e-4, "\(aspect) at \(angle)°")
        }
    }

    /// MJ6L: J6's live geometry and pixels without the app.
    @Test func walkJ6Live() throws {
        var catalog = cropLiveLoupe()
        #expect(catalog.cropHelp == nil)
        catalog.toggleCrop()
        #expect(catalog.cropFrameValue == "6000 × 4000 at 0, 0")
        catalog.setCropAspect(.square)
        #expect(catalog.cropFrameValue?.hasPrefix("4000 × 4000") == true)
        catalog.setCropAngle(5)
        let frame = try #require(catalog.cropFrame)
        #expect((3544...3546).contains(frame.width) && abs(frame.width - frame.height) <= 1)
        #expect(cropLies(frame, inside: try cropStraightened(PixelSize(width: 6000, height: 4000), degrees: 5)))
        #expect(catalog.history.undo.isEmpty)

        let draft = try #require(catalog.cropDraft)
        let gradient = try developGradient(width: 600, height: 400)
        let out = try develop.render(gradient, settings: DevelopSettings.neutral.setting(crop: draft))
        #expect(abs(out.width - out.height) <= 1)
        #expect(try cropEveryPixelIsOpaque(out))

        catalog.toggleCrop()
        #expect(catalog.cropDraft == nil)
        #expect(catalog.undoTitle == "Undo Crop")
        let photo = try #require(catalog.items.first { $0.id == "/fixture/shoot/IMG_0001.jpg" })
        #expect(photo.develop.crop == draft)
        #expect(catalog.croppedSize(photo) == PixelSize(width: frame.width, height: frame.height))
    }
}
