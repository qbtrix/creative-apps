// SuiteGridActiveTests.swift: ThumbnailGrid's active cell (#3636). With
// several photos selected, the one an app acts from (Library's Sync source)
// draws a heavier accent ring than the other selected cells. Rendered
// offscreen in Light and Dark: a selected cell marked `active` shows more
// accent pixels than the same cell selected but not active, and an active id
// that isn't selected draws nothing extra. macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteGridActiveTests {
    private func grid(selected: Set<String>, active: String?) -> some View {
        ThumbnailGrid(
            [ThumbnailItem(id: "a", caption: "a.heic")], cellSize: CGSize(width: 160, height: 120),
            selection: selected, onSelectionChange: { _ in }, active: active)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func theActiveCellHasAHeavierRing(_ scheme: ColorScheme) throws {
        let plain = try #require(render(grid(selected: ["a"], active: nil), scheme: scheme))
        let active = try #require(render(grid(selected: ["a"], active: "a"), scheme: scheme))
        let unselected = try #require(render(grid(selected: [], active: "a"), scheme: scheme))
        let ring = Self.accentPixels(plain)
        #expect(ring > 0, "no accent ring on a selected cell (\(scheme))")
        #expect(Self.accentPixels(active) > ring + 100, "the active ring is no heavier (\(scheme))")
        #expect(Self.accentPixels(unselected) == 0, "an unselected active id draws a ring (\(scheme))")
    }

    /// Pixels within a few sRGB steps of the accent, #1877F2, in the leading 400 points (the grid centres vertically).
    private static func accentPixels(_ image: NSBitmapImageRep) -> Int {
        var count = 0
        for y in 0..<image.pixelsHigh {
            for x in 0..<400 {
                guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let rgb = [c.redComponent, c.greenComponent, c.blueComponent].map { Double($0) * 255 }
                if zip(rgb, [24.0, 119, 242]).allSatisfy({ abs($0 - $1) <= 6 }) { count += 1 }
            }
        }
        return count
    }
}
