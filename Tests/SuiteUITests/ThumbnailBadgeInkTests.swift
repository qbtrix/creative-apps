// ThumbnailBadgeInkTests.swift: a thumbnail's reject mark reads as strongly as
// its other badges. The reject glyph sat beside solid stars as a hairline
// outline that all but vanished at caption size (Library mac finish pass), so
// this renders one cell per badge and compares the dark ink each adds over a
// cell with no badge. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct ThumbnailBadgeInkTests {
    /// Dark pixels in a one-cell grid drawn in Light with `badges`.
    static func ink(_ badges: ThumbnailBadges) throws -> Int {
        let grid = ThumbnailGrid(
            [ThumbnailItem(id: 1, caption: "a.heic", badges: badges)], cellSize: CGSize(width: 120, height: 90),
            selection: [], onSelectionChange: { _ in })
            .environment(\.suiteSnapshotRendering, true)
            .environment(\.colorScheme, .light)
            .frame(width: 200, height: 160)
            .background(Color.white)
        let renderer = ImageRenderer(content: grid)
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "no image")
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: bytes.count, by: 4).filter { i in
            bytes[i] < 110 && bytes[i + 1] < 110 && bytes[i + 2] < 110
        }.count
    }

    @Test func theRejectMarkInksAtLeastAsMuchAsOneStar() throws {
        let none = try Self.ink(ThumbnailBadges())
        let star = try Self.ink(ThumbnailBadges(rating: 1)) - none
        let reject = try Self.ink(ThumbnailBadges(dimmed: true)) - none
        #expect(star > 0)
        #expect(reject >= star, "reject \(reject) dark pixels, one star \(star)")
    }
}
