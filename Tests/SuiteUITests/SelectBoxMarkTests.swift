// SelectBoxMarkTests.swift: SelectBoxMark's edge stays visible over any picture, like every other canvas
// mark: over the accent's own blue (a sky in a photo) its paper halo shows, over white its accent ink does.
// At 1x the 1 pt edge straddles two pixel rows, so each reads half-mixed (red 24 for bare accent, about 140 with
// the halo). PickOutlineMark draws the same edge round each picked box, with no fill.
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

    /// PickOutlineMark edges both boxes on their halo and leaves their insides unfilled.
    @Test func pickOutlinesEdgeEveryBoxWithoutAFill() throws {
        let view = ZStack(alignment: .topLeading) {
            SuiteColor.accent
            PickOutlineMark(rects: [CGRect(x: 10, y: 10, width: 30, height: 30), CGRect(x: 60, y: 60, width: 30, height: 30)], zoom: 1)
        }
        let bytes = try AppMarkTests.pixels(view, side: 100)
        func red(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * 100 + x) * 4] }
        let accent = red(50, 50)
        #expect([9, 10, 11].map { red(25, $0) }.contains { $0 > 100 }, "no halo on the first box's top edge")
        #expect([59, 60, 61].map { red(75, $0) }.contains { $0 > 100 }, "no halo on the second box's top edge")
        #expect(red(25, 25) == accent && red(75, 75) == accent, "a picked box is filled")
    }

    @Test func theEdgeShowsOverWhite() throws {
        let reds = try Self.edgeReds(over: .white)
        #expect(reds.contains { $0 < 150 }, "no accent ink over white: \(reds)")
    }
}
#endif
