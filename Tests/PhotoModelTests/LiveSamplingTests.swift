// LiveSamplingTests.swift: PE-5 of eyedropper, the live `ColorSampling`.
// It returns SuiteKernel's mean of the `size` square centred on the point,
// skips fully transparent pixels, and gives nil when nothing it reads is
// inside the picture or opaque. Pictures are built from straight sRGB bytes,
// so the expected colours are exact. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct LiveSamplingTests {
    private let sampling = LiveSampling.make()

    /// A `width` x `height` picture whose pixel (x, y) is `color(x, y)`, as
    /// straight sRGB bytes.
    private func picture(_ width: Int, _ height: Int, _ color: (Int, Int) -> [UInt8]) throws -> PixelBuffer {
        var bytes: [UInt8] = []
        for y in 0..<height { for x in 0..<width { bytes += color(x, y) } }
        return try PixelBuffer(rgba8: bytes, width: width, height: height)
    }

    /// Columns 0 to 2 red, 3 and 4 blue.
    private func redBlue() throws -> PixelBuffer {
        try picture(5, 5) { x, _ in x < 3 ? [255, 0, 0, 255] : [0, 0, 255, 255] }
    }

    @Test func liveIsBuilt() {
        #expect(sampling.unavailableHelp == nil)
    }

    /// squareCentred: the 3 x 3 at (3, 2) reads columns 2 to 4, one red and
    /// two blue; anchored anywhere else it reads another mix.
    @Test func meanOfTheSquareCentredOnThePoint() throws {
        let image = try redBlue()
        #expect(sampling.sample(image, center: (x: 3, y: 2), size: .threeByThree)
            == SampledColor(red: 85, green: 0, blue: 170))
        #expect(sampling.sample(image, center: (x: 1, y: 2), size: .threeByThree)
            == SampledColor(red: 255, green: 0, blue: 0))
        #expect(sampling.sample(image, center: (x: 4, y: 4), size: .point) == SampledColor(red: 0, green: 0, blue: 255))
        #expect(sampling.sample(image, center: (x: 2, y: 2), size: .fiveByFive)
            == SampledColor(red: 153, green: 0, blue: 102))
    }

    /// skipsTransparent: one opaque green pixel among transparent ones reads
    /// pure green, and an all-transparent square reads nil.
    @Test func transparentPixelsAreSkipped() throws {
        let image = try picture(3, 3) { x, y in x == 1 && y == 1 ? [0, 255, 0, 255] : [0, 0, 0, 0] }
        #expect(sampling.sample(image, center: (x: 1, y: 1), size: .threeByThree)
            == SampledColor(red: 0, green: 255, blue: 0))
        #expect(sampling.sample(image, center: (x: 0, y: 0), size: .point) == nil)
    }

    /// A square wholly outside the picture reads nil; one over its edge
    /// averages only the pixels inside.
    @Test func outsideTheImageIsNil() throws {
        let image = try redBlue()
        #expect(sampling.sample(image, center: (x: -3, y: -3), size: .threeByThree) == nil)
        #expect(sampling.sample(image, center: (x: 5, y: 0), size: .point) == nil)
        #expect(sampling.sample(image, center: (x: 9, y: 9), size: .fiveByFive) == nil)
        #expect(sampling.sample(image, center: (x: 5, y: 2), size: .threeByThree)
            == SampledColor(red: 0, green: 0, blue: 255))
    }
}
