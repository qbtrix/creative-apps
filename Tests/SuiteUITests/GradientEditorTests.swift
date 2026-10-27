// GradientEditorTests.swift (gradient-fill GF-3): the gradient editor's stop bar as intents, through its pure
// `GradientBarDrag`. A click on the bar is one `.add` at its offset, a drag on a stop is `.move`s under one token, a
// drag 40 pt off the bar is one `.remove`, a two-stop remove is refused with the help; the angle row shows only for a
// linear fill; a stop reads "Stop n of m, p percent, colour"; the end stops' handles sit half a handle inside the
// bar's row and a press on one picks its stop; the colour row names the selected stop and the Location row reads its
// offset in percent; the type switch is a system
// segmented Picker under its identifier prefix; the bar dims while the editor is off. macOS only.
import AppKit
import CoreGraphics
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@Suite struct GradientEditorTests {
    static let blue = FillColor(r: 0, g: 0, b: 1), red = FillColor(r: 1, g: 0, b: 0)
    /// Blue at 0, red at 0.5, white at 1, left to right on a 200-wide box.
    static let three = Fill.linear(
        stops: [GradientStop(offset: 0, color: blue), GradientStop(offset: 0.5, color: red), GradientStop(offset: 1, color: .white)],
        start: Point(x: 0, y: 10), end: Point(x: 200, y: 10))
    static let two = Fill.linear(stops: [three.stops[0], three.stops[2]], start: Point(x: 0, y: 10), end: Point(x: 200, y: 10))
    /// A 212-wide row with 12 pt handles: offsets 0...1 run from x 6 to x 206, 2 pt per percent.
    static let width: CGFloat = 212

    @Test func clickAddsOneStopAtItsOffset() {
        var drag = GradientBarDrag(at: CGPoint(x: 56, y: 10), width: Self.width, fill: Self.three, token: "t")
        #expect(drag.stop == nil)
        let moved = drag.changed(to: CGPoint(x: 57, y: 10), fill: Self.three)
        let released = drag.ended(at: CGPoint(x: 57, y: 10), fill: Self.three)
        #expect(moved == nil && released == .add(offset: 0.25))
    }

    @Test func dragMovesUnderOneToken() {
        var drag = GradientBarDrag(at: CGPoint(x: 107, y: 12), width: Self.width, fill: Self.three, token: "t")
        #expect(drag.stop == 1)
        let intents = [126.0, 146, 166].compactMap { drag.changed(to: CGPoint(x: $0, y: 12), fill: Self.three) }
        #expect(intents == [.move(index: 1, offset: 0.6, drag: "t"), .move(index: 1, offset: 0.7, drag: "t"),
                            .move(index: 1, offset: 0.8, drag: "t")])
        let released = drag.ended(at: CGPoint(x: 166, y: 12), fill: Self.three)
        #expect(released == nil)
    }

    @Test func dragPastTheEndsClamps() {
        var drag = GradientBarDrag(at: CGPoint(x: 106, y: 10), width: Self.width, fill: Self.three, token: "t")
        let moved = drag.changed(to: CGPoint(x: 400, y: 10), fill: Self.three)
        #expect(moved == .move(index: 1, offset: 1, drag: "t"))
    }

    @Test func dragOffRemovesOnce() {
        var drag = GradientBarDrag(at: CGPoint(x: 106, y: 10), width: Self.width, fill: Self.three, token: "t")
        let off = drag.changed(to: CGPoint(x: 106, y: 55), fill: Self.three)
        let removed = drag.ended(at: CGPoint(x: 106, y: 55), fill: Self.three)
        #expect(off == nil && removed == .remove(index: 1))
        var near = GradientBarDrag(at: CGPoint(x: 106, y: 10), width: Self.width, fill: Self.three, token: "t")
        _ = near.changed(to: CGPoint(x: 106, y: 45), fill: Self.three)
        let kept = near.ended(at: CGPoint(x: 106, y: 45), fill: Self.three)
        #expect(kept == nil)
    }

    @Test func twoStopsRefuseTheRemove() {
        var drag = GradientBarDrag(at: CGPoint(x: 6, y: 10), width: Self.width, fill: Self.two, token: "t")
        let released = drag.ended(at: CGPoint(x: 6, y: 60), fill: Self.two)
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
        let half = GradientEditor.handleSize / 2
        #expect(GradientBarDrag.x(of: 0, width: Self.width) >= half, "the first stop's handle hangs past the row's left edge")
        #expect(GradientBarDrag.x(of: 1, width: Self.width) <= Self.width - half, "the last stop's handle hangs past the right edge")
        for (offset, stop) in [(0.0, 0), (0.5, 1), (1.0, 2)] {
            let press = CGPoint(x: GradientBarDrag.x(of: offset, width: Self.width), y: 20)
            let drag = GradientBarDrag(at: press, width: Self.width, fill: Self.three, token: "t")
            #expect(drag.stop == stop, "a press on stop \(stop)'s handle picks \(String(describing: drag.stop))")
        }
    }

    @Test func colorRowNamesTheSelectedStop() {
        #expect(GradientEditorText.selectedStop(1, of: Self.three) == "Stop 2 · 50%")
        #expect(GradientEditorText.selectedStop(0, of: .solid(Self.red)) == "Color")
    }

    @Test func locationReadsTheSelectedStopInPercent() {
        #expect(GradientEditorText.location(0.5) == "50%")
        #expect(GradientEditorText.percent(Self.three.stops[1].offset) == 50)
        #expect(GradientEditorText.offset(percent: 25) == 0.25)
        #expect(GradientEditorText.offset(percent: 140) == 1 && GradientEditorText.offset(percent: -5) == 0)
        #expect(GradientEditorText.offset(percent: .nan) == 0)
    }

    @Test func typeSwitchIsSharedAndNamesItsNote() {
        #expect(GradientTypeSwitch.typeID(.linear, in: GradientTypeSwitch.defaultID) == "suite.gradient.type.linear")
        #expect(GradientTypeSwitch.helpID(in: "design.inspector.fill-type") == "design.inspector.fill-type.help")
    }

    /// A solid's own switch is the same segmented Picker the editor shows.
    @MainActor @Test func solidTypeSwitchIsASegmentedPicker() {
        let host = NSHostingView(rootView: GradientTypeSwitch(type: .solid) { _ in }.frame(width: 260))
        host.frame = CGRect(x: 0, y: 0, width: 260, height: 80)
        host.layoutSubtreeIfNeeded()
        func segmented(in view: NSView) -> [NSSegmentedControl] {
            (view as? NSSegmentedControl).map { [$0] } ?? view.subviews.flatMap(segmented)
        }
        #expect(segmented(in: host).map(\.segmentCount) == [3], "the solid switch is not a segmented Picker")
    }

    @Test func typeSwitchTakesAPrefix() {
        #expect(GradientEditor.typeID(.radial, in: "suite.gradient.type") == "suite.gradient.type.radial")
        #expect(GradientEditor.typeID(.solid, in: "flare.inspector.fillType") == "flare.inspector.fillType.solid")
    }

    /// Looks for the AppKit control a segmented Picker hosts, as SegmentedTabsTests does (#2714).
    @MainActor @Test func typeSwitchIsASegmentedPicker() {
        let editor = GradientEditor(fill: Self.three, box: Rect(minX: 0, minY: 0, maxX: 200, maxY: 20)) { _ in }
        let host = NSHostingView(rootView: editor.frame(width: 260))
        host.frame = CGRect(x: 0, y: 0, width: 260, height: 200)
        host.layoutSubtreeIfNeeded()
        func segmented(in view: NSView) -> [NSSegmentedControl] {
            (view as? NSSegmentedControl).map { [$0] } ?? view.subviews.flatMap(segmented)
        }
        #expect(segmented(in: host).map(\.segmentCount) == [3], "the type switch is not a segmented Picker")
    }

    @Test func barDimsWhileOff() {
        #expect(GradientEditor.barOpacity(enabled: true) == 1)
        #expect(GradientEditor.barOpacity(enabled: false) == SuiteColor.disabledOpacity)
    }
}
