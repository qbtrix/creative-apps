// LibraryLoupeSurroundTests.swift: the loupe reads as a photo viewer, not a
// design canvas (#3631). Rendered offscreen in Light and Dark, the strip down
// the leading edge where CanvasViewport draws its vertical ruler is plain
// surround (no ruler panel, ticks or labels), and that surround is the fixed
// dark one: canvasSurround's Dark value in both appearances. macOS only.
@testable import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryLoupeSurroundTests {
    @Test(arguments: [ColorScheme.light, .dark])
    func loupeHasNoRulersOnADarkSurround(_ scheme: ColorScheme) throws {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let photo = try #require(catalog.sortedItems.first)
        catalog.open(photo.id)
        let image = try #require(render(LibraryBrowser(model: catalog), scheme: scheme))
        let surround = SuitePaletteDark.canvasSurround
        // The vertical ruler's band, below the Grid button and above the readout.
        var off = 0
        for y in stride(from: 200, to: 700, by: 4) {
            for x in 4..<16 where !Self.near(image, x: x, y: y, hex: surround) { off += 1 }
        }
        #expect(off == 0, "\(off) pixels in the leading band aren't the dark surround (\(scheme))")
    }

    /// Whether the pixel at (x, y) is within a few sRGB steps of `hex`.
    private static func near(_ image: NSBitmapImageRep, x: Int, y: Int, hex: UInt32) -> Bool {
        guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
        let target = [hex >> 16 & 0xFF, hex >> 8 & 0xFF, hex & 0xFF].map(Double.init)
        let rgb = [c.redComponent, c.greenComponent, c.blueComponent].map { Double($0) * 255 }
        return zip(rgb, target).allSatisfy { abs($0 - $1) <= 3 }
    }
}

/// canvasSurround's Dark hex (docs/design.md's ladder).
private enum SuitePaletteDark {
    static let canvasSurround: UInt32 = 0x18191B
}
