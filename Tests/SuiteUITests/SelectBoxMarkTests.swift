// SelectBoxMarkTests.swift: SelectBoxMark's edge stays visible over any picture, like every other canvas
// mark: over the accent's own blue (a sky in a photo) its paper halo shows, over white its accent ink does.
// At 1x the 1 pt edge straddles two pixel rows, so each reads half-mixed (red 24 for bare accent, about 140 with
// the halo).
// macOS only.
#if canImport(AppKit)
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SelectBoxMarkTests {
    /// The red channel of the pixels in column 50 from row 14 to 26, across the box's top edge at row 20.
    static func edgeReds(over under: Color) throws -> [UInt8] {
        let view = ZStack(alignment: .topLeading) {
            under
            SelectBoxMark(rect: CGRect(x: 20, y: 20, width: 60, height: 60), zoom: 1)
        }
        let bytes = try AppMarkTests.pixels(view, side: 100)
        return (14...26).map { bytes[($0 * 100 + 50) * 4] }
    }

    @Test func theEdgeShowsOverTheAccent() throws {
        let reds = try Self.edgeReds(over: SuiteColor.accent)
        #expect(reds.contains { $0 > 100 }, "no paper halo over the accent: \(reds)")
    }

    @Test func theEdgeShowsOverWhite() throws {
        let reds = try Self.edgeReds(over: .white)
        #expect(reds.contains { $0 < 150 }, "no accent ink over white: \(reds)")
    }
}
#endif
