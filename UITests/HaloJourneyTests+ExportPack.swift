// HaloJourneyTests+ExportPack.swift: HJ-X1 (export-pack), a movie that keeps
// transparency. On `-HaloSample keyed -HaloRenderTo <tmp>` (Bounce on live
// services) it opens File > Render…, picks Movie, and reads the Codec row
// (`halo.render.codec`) on H.264 with Transparent background
// (`halo.render.alpha`) off and disabled, its help "H.264 can't keep
// transparency. Choose ProRes 4444." Then it picks ProRes 4444, ticks the
// checkbox and starts: `<tmp>/Bounce.mov` is written, and its first frame
// has alpha 0 in the corner, where the composition has only its background.
// Written first (HX-6): skips until HX-7 turns it on, once HX-3's plan rules
// and HX-4's writer let ProRes 4444 through. The Model half is
// HaloProResTests. One shot per step, `halo-export-pack-<n>-<step>`.
import AVFoundation
import CoreGraphics
import XCTest

final class HaloExportPackJourneyTests: XCTestCase {
    /// ExportRules' sentence for alpha on H.264, the checkbox's help.
    private static let h264Alpha = "H.264 can't keep transparency. Choose ProRes 4444."

    /// HJ-X1: Render… refuses alpha on H.264, then writes Bounce.mov in ProRes 4444 with alpha.
    @MainActor func testRenderLowerThirdWithAlpha() throws {
        throw XCTSkip("waits on HX-7")
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-export-pack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }

        // 1. File > Render…, Movie: Codec reads H.264; Transparent background is off, disabled, and says why.
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "keyed", "-HaloRenderTo", folder.path,
                                                     "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        openRenderSheet(halo)
        click("halo.render.format.movie", halo)
        let codec = halo.element("halo.render.codec")
        XCTAssert(codec.waitForExistence(timeout: 5), "no Codec row (halo.render.codec)")
        XCTAssertEqual(codec.value as? String, "H.264", "the Codec row doesn't start on H.264")
        let alpha = halo.element("halo.render.alpha")
        XCTAssert(alpha.waitForExistence(timeout: 5), "no Transparent background (halo.render.alpha)")
        XCTAssertFalse(alpha.isEnabled, "Transparent background is enabled on H.264")
        XCTAssertEqual(alpha.value as? Int, 0, "Transparent background is on with H.264")
        alpha.hover()
        let tip = halo.app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", Self.h264Alpha)).firstMatch
        XCTAssert(tip.waitForExistence(timeout: 5), "the checkbox's help doesn't read \(Self.h264Alpha)")
        halo.shot("export-pack-1-h264")

        // 2. ProRes 4444, tick Transparent background, start: Bounce.mov is written.
        codec.click()
        let prores = halo.app.menuItems["ProRes 4444"]
        XCTAssert(prores.waitForExistence(timeout: 3), "the Codec menu has no ProRes 4444")
        XCTAssert(prores.isEnabled, "ProRes 4444 is disabled")
        prores.click()
        XCTAssert(waitFor { alpha.isEnabled }, "Transparent background stays disabled on ProRes 4444")
        alpha.click()
        XCTAssertEqual(alpha.value as? Int, 1, "Transparent background didn't tick")
        halo.shot("export-pack-2-prores-alpha")
        let start = halo.element("halo.render.start")
        XCTAssert(start.waitForExistence(timeout: 5), "no start button (halo.render.start)")
        start.click()
        XCTAssert(halo.element("halo.render.reveal").waitForExistence(timeout: 120), "the render never finished")
        halo.shot("export-pack-3-done")
        let movie = folder.appending(path: "Bounce.mov")
        XCTAssert(FileManager.default.fileExists(atPath: movie.path), "no Bounce.mov in \(folder.path)")

        // 3. The movie's first frame is transparent in the corner, where Bounce has only its background.
        let frame = try XCTUnwrap(firstFrame(of: movie), "Bounce.mov's first frame can't be read")
        XCTAssertEqual(cornerAlpha(of: frame), 0, "the background was drawn into an alpha movie")
    }

    // MARK: - Helpers

    /// File > Render…; the sheet's Format picker shows.
    @MainActor private func openRenderSheet(_ halo: Journey) {
        let file = halo.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Render…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Render…")
        item.click()
        XCTAssert(halo.element("halo.render.format").waitForExistence(timeout: 10), "no Render sheet (halo.render.format)")
    }

    @MainActor private func click(_ id: String, _ halo: Journey) {
        let element = halo.element(id)
        XCTAssert(element.waitForExistence(timeout: 5), "no \(id)")
        element.click()
    }

    /// The movie's frame at time zero, decoded by AVFoundation with its alpha.
    private func firstFrame(of url: URL) -> CGImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let done = expectation(description: "first frame of \(url.lastPathComponent)")
        nonisolated(unsafe) var image: CGImage?
        generator.generateCGImageAsynchronously(for: .zero) { frame, _, _ in
            image = frame
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        return image
    }

    /// The alpha (0 to 255) of the top-left pixel, drawn into an 8-bit RGBA context.
    private func cornerAlpha(of image: CGImage) -> UInt8? {
        var pixel = [UInt8](repeating: 0, count: 4)
        let drawn = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                          bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            // The image's top-left pixel lands on the 1 × 1 context (CoreGraphics' origin is bottom-left).
            context.draw(image, in: CGRect(x: 0, y: 1 - image.height, width: image.width, height: image.height))
            return true
        }
        return drawn ? pixel[3] : nil
    }

    @MainActor private func waitFor(seconds: Int = 3, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
