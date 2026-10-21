// GradientEditorTests.swift (gradient-fill GF-3): the gradient editor's stop bar as intents, through its pure
// `GradientBarDrag`. A click on the bar is one `.add` at its offset, a drag on a stop is `.move`s under one token, a
// drag 40 pt off the bar is one `.remove`, a two-stop remove is refused with the help; the angle row shows only for a
// linear fill; a stop reads "Stop n of m, p percent, colour"; the end stops' handles stay inside the bar's row, and a
// press on a handle there still picks its stop; the bar dims while the editor is off. No rendering here. macOS only.
import CoreGraphics
import SuiteKernel
@testable import SuiteUI
import Testing

@Suite struct GradientEditorTests {
    static let blue = FillColor(r: 0, g: 0, b: 1), red = FillColor(r: 1, g: 0, b: 0)
    /// Blue at 0, red at 0.5, white at 1, left to right on a 200-wide box.
    static let three = Fill.linear(
        stops: [GradientStop(offset: 0, color: blue), GradientStop(offset: 0.5, color: red), GradientStop(offset: 1, color: .white)],
        start: Point(x: 0, y: 10), end: Point(x: 200, y: 10))
    static let two = Fill.linear(stops: [three.stops[0], three.stops[2]], start: Point(x: 0, y: 10), end: Point(x: 200, y: 10))
    static let width: CGFloat = 200

    @Test func clickAddsOneStopAtItsOffset() {
        var drag = GradientBarDrag(at: CGPoint(x: 50, y: 10), width: Self.width, fill: Self.three, token: "t")
        #expect(drag.stop == nil)
        let moved = drag.changed(to: CGPoint(x: 51, y: 10), fill: Self.three)
        let released = drag.ended(at: CGPoint(x: 51, y: 10), fill: Self.three)
        #expect(moved == nil && released == .add(offset: 0.25))
    }

    @Test func dragMovesUnderOneToken() {
        var drag = GradientBarDrag(at: CGPoint(x: 101, y: 12), width: Self.width, fill: Self.three, token: "t")
        #expect(drag.stop == 1)
        let intents = [120.0, 140, 160].compactMap { drag.changed(to: CGPoint(x: $0, y: 12), fill: Self.three) }
        #expect(intents == [.move(index: 1, offset: 0.6, drag: "t"), .move(index: 1, offset: 0.7, drag: "t"),
                            .move(index: 1, offset: 0.8, drag: "t")])
        let released = drag.ended(at: CGPoint(x: 160, y: 12), fill: Self.three)
        #expect(released == nil)
    }

    @Test func dragPastTheEndsClamps() {
        var drag = GradientBarDrag(at: CGPoint(x: 100, y: 10), width: Self.width, fill: Self.three, token: "t")
        let moved = drag.changed(to: CGPoint(x: 400, y: 10), fill: Self.three)
        #expect(moved == .move(index: 1, offset: 1, drag: "t"))
    }

    @Test func dragOffRemovesOnce() {
        var drag = GradientBarDrag(at: CGPoint(x: 100, y: 10), width: Self.width, fill: Self.three, token: "t")
        let off = drag.changed(to: CGPoint(x: 100, y: 55), fill: Self.three)
        let removed = drag.ended(at: CGPoint(x: 100, y: 55), fill: Self.three)
        #expect(off == nil && removed == .remove(index: 1))
        var near = GradientBarDrag(at: CGPoint(x: 100, y: 10), width: Self.width, fill: Self.three, token: "t")
        _ = near.changed(to: CGPoint(x: 100, y: 45), fill: Self.three)
        let kept = near.ended(at: CGPoint(x: 100, y: 45), fill: Self.three)
        #expect(kept == nil)
    }

    @Test func twoStopsRefuseTheRemove() {
        var drag = GradientBarDrag(at: CGPoint(x: 0, y: 10), width: Self.width, fill: Self.two, token: "t")
        let released = drag.ended(at: CGPoint(x: 0, y: 60), fill: Self.two)
        #expect(released == nil && drag.refused)
    }

    @Test func angleRowOnlyForLinear() {
        let radial = Fill.radial(stops: Self.three.stops, center: Point(x: 100, y: 10), radius: 100)
        #expect(GradientEditor.showsAngleRow(Self.three, showsAngle: true))
        #expect(!GradientEditor.showsAngleRow(Self.three, showsAngle: false))
        #expect(!GradientEditor.showsAngleRow(radial, showsAngle: true))
        #expect(!GradientEditor.showsAngleRow(.solid(Self.red), showsAngle: true))
    }

    @Test func stopReadsItsPlaceAndColor() {
        #expect(GradientEditorText.stop(1, of: Self.three) == "Stop 2 of 3, 50 percent, red")
        #expect(GradientEditorText.colorName(Self.blue) == "blue" && GradientEditorText.colorName(.white) == "white")
        #expect(GradientEditorText.colorName(FillColor(r: 0.5, g: 0.5, b: 0.5)) == "grey")
    }

    @Test func endHandlesStayInsideTheRow() {
        let row: CGFloat = 192, half = GradientEditor.trackInset
        #expect(GradientEditor.handleX(0, width: row) - half >= 0, "the first stop's handle hangs past the row's left edge")
        #expect(GradientEditor.handleX(1, width: row) + half <= row, "the last stop's handle hangs past the row's right edge")
        let track = GradientEditor.trackWidth(row)
        for (offset, stop) in [(0.0, 0), (0.5, 1), (1.0, 2)] {
            let press = GradientEditor.trackPoint(CGPoint(x: GradientEditor.handleX(offset, width: row), y: 20))
            let drag = GradientBarDrag(at: press, width: track, fill: Self.three, token: "t")
            #expect(drag.stop == stop, "a press on stop \(stop)'s handle picks \(String(describing: drag.stop))")
        }
    }

    @Test func barDimsWhileOff() {
        #expect(GradientEditor.barOpacity(enabled: true) == 1)
        #expect(GradientEditor.barOpacity(enabled: false) == SuiteColor.disabledOpacity)
    }
}
