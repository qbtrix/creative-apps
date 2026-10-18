// CurveEditorTests.swift: the math behind SuiteUI's CurveEditor: the curve is
// one vector path, the plot range widens for overshoot, the preview dot never
// leaves the samples, arrow-key nudges step by 0.01 (0.1 with Shift), and a
// handle looks different at rest, under the pointer and pressed or focused.
// IC-8: a handle's x clamps to 0...1, SuiteEasingHandleNudging (UC15b) nudges
// ↑ 0.01 and ⇧↑ 0.1 and speaks the handle, one end per drag or nudge
// (CurveEnds), the drag series and the Reduce Motion preview mark.
// Mutating calls go into a local first: #expect can't call a mutating member.
// No rendering here. macOS only.
import CoreGraphics
@testable import SuiteUI
import SwiftUI
import Testing

@Test func curveIsOneVectorPath() {
    let samples = (0...128).map { CGPoint(x: Double($0) / 128, y: Double($0) / 128) }
    let path = CurveEditor.curvePath(samples, in: CGRect(x: 12, y: 12, width: 212, height: 156), range: -0.25...1.25)
    var moves = 0, lines = 0, other = 0
    path.forEach { element in
        switch element {
        case .move: moves += 1
        case .line: lines += 1
        default: other += 1
        }
    }
    #expect(moves == 1 && lines == 128 && other == 0)
    #expect(CurveEditor.curvePath([], in: .zero, range: 0...1).isEmpty)
}

@Test func plotRangeWidensForOvershoot() {
    #expect(CurveEditor.plotRange(including: []) == -0.25...1.25)
    #expect(CurveEditor.plotRange(including: [CGPoint(x: 0.4, y: 0), CGPoint(x: 0.2, y: 1)]) == -0.25...1.25)
    #expect(CurveEditor.plotRange(including: [CGPoint(x: 0.4, y: 1.6), CGPoint(x: 0.2, y: -0.5)]) == -0.5...1.6)
    #expect(CurveEditor.plotRange(including: [CGPoint(x: 0, y: CGFloat.nan), CGPoint(x: 0, y: CGFloat.infinity)]) == -0.25...1.25)
    // The top of the range maps to the top of the plot, and back.
    let plot = CGRect(x: 12, y: 12, width: 212, height: 156)
    let top = CurveEditor.viewPoint(CGPoint(x: 1, y: 1.6), in: plot, range: -0.5...1.6)
    #expect(top == CGPoint(x: 224, y: 12))
    let back = CurveEditor.unitPoint(top, in: plot, range: -0.5...1.6)
    #expect(abs(back.x - 1) < 1e-9 && abs(back.y - 1.6) < 1e-9)
    #expect(CurveEditor.unitPoint(top, in: .zero, range: 0...1) == .zero)
}

@Test func previewPointStaysInsideTheSamples() {
    let samples = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 0.2), CGPoint(x: 1, y: 1)]
    #expect(CurveEditor.previewPoint(samples: samples, phase: -3) == samples[0])
    #expect(CurveEditor.previewPoint(samples: samples, phase: 7) == samples[2])
    #expect(CurveEditor.previewPoint(samples: samples, phase: .nan) == samples[0])
    #expect(CurveEditor.previewPoint(samples: samples, phase: 0.25) == CGPoint(x: 0.25, y: 0.1))
    #expect(CurveEditor.previewPoint(samples: [], phase: 0.5) == .zero)
    #expect(CurveEditor.previewPoint(samples: [samples[1]], phase: 0.5) == samples[1])
    // 1.2 s along the curve, then 0.4 s resting at its end.
    #expect(CurveEditor.previewPhase(at: 0.6) == 0.5)
    #expect(CurveEditor.previewPhase(at: 1.4) == 1)
    #expect(CurveEditor.previewPhase(at: .infinity) == 0)
}

@Test func nudgeSteps() {
    let p = CGPoint(x: 0.42, y: 0)
    #expect(CurveEditor.nudged(p, dx: 1, dy: 0, coarse: false) == CGPoint(x: 0.43, y: 0))
    #expect(CurveEditor.nudged(p, dx: 0, dy: -1, coarse: true) == CGPoint(x: 0.42, y: -0.1))
    #expect(CurveEditor.nudged(CGPoint(x: 0.95, y: 1.3), dx: 1, dy: 1, coarse: true) == CGPoint(x: 1, y: 1.4))
    // Five nudges right from 0.42 land on 0.47 exactly.
    var q = p
    for _ in 0..<5 { q = CurveEditor.nudged(q, dx: 1, dy: 0, coarse: false) }
    #expect(q.x == 0.47)
    #expect(CurveEditor.describe(CGPoint(x: 0.42, y: 0)) == "x 0.42, y 0.00")
}

@Test func handleShowsHoverPressedAndFocus() {
    let rest = CurveEditor.handleLook(active: false, hovered: false)
    let hover = CurveEditor.handleLook(active: false, hovered: true)
    let active = CurveEditor.handleLook(active: true, hovered: false)
    // Under the pointer the handle's rim turns accent, so it reads as grabbable before the press.
    #expect(rest.stroke != hover.stroke)
    #expect(hover.stroke == SuiteColor.accent && hover.fill == rest.fill)
    // Pressed, dragged or focused: filled accent, ringed; hover adds nothing on top.
    #expect(active.fill == SuiteColor.accent && active.ring)
    #expect(CurveEditor.handleLook(active: true, hovered: true) == active)
    #expect(!rest.ring && !hover.ring)
}

@Test func handleXClampsToTheUnitRange() {
    #expect(CurveEditor.handlePoint(CGPoint(x: -0.3, y: 1.4)) == CGPoint(x: 0, y: 1.4))
    #expect(CurveEditor.handlePoint(CGPoint(x: 1.7, y: -0.6)) == CGPoint(x: 1, y: -0.6))
    #expect(CurveEditor.handlePoint(CGPoint(x: CGFloat.nan, y: CGFloat.infinity)) == .zero)
    // A nudge on a handle already outside 0...1 lands it inside, even up or down.
    #expect(CurveEditor.nudged(CGPoint(x: 1.2, y: 0.5), dx: 0, dy: 1, coarse: false) == CGPoint(x: 1, y: 0.51))
    #expect(CurveEditor.nudged(CGPoint(x: 0.005, y: 0), dx: -1, dy: 0, coarse: true).x == 0)
}

@Test func suiteNudgingStepsAndSpeaks() {
    let n = SuiteEasingHandleNudging()
    let h = PlanePoint(x: 0.42, y: 1)
    #expect(n.nudged(h, dx: 0, dy: 1, coarse: false) == PlanePoint(x: 0.42, y: 1.01))
    #expect(n.nudged(h, dx: 0, dy: 1, coarse: true) == PlanePoint(x: 0.42, y: 1.1))
    #expect(n.nudged(PlanePoint(x: 0.98, y: 0), dx: 1, dy: 0, coarse: true).x == 1)
    #expect(n.describe(PlanePoint(x: 0.42, y: 1.1)) == "x 0.42, y 1.10")
    // The Fake leaves x unclamped; the suite's conformance doesn't.
    #expect(FakeEasingHandleNudging().nudged(PlanePoint(x: 0.98, y: 0), dx: 1, dy: 0, coarse: true).x > 1)
}

@Test func oneEndPerDragOrNudge() {
    var ends = CurveEnds()
    var opened = 0, fired = 0
    for _ in 0..<5 where ends.dragged() { opened += 1 }
    if ends.released() { fired += 1 }
    if ends.released() { fired += 1 }   // a second release ends nothing
    if ends.nudged() { fired += 1 }     // ↑
    if ends.nudged() { fired += 1 }     // ⇧↑
    let total = ends.ends
    #expect(opened == 1 && fired == 3 && total == 3 && !ends.isOpen)
}

@Test func probeSeriesAndPreviewMark() {
    #expect(CurveProbe.sample(eventTime: 1, shownAt: 2) == ProbeSample(series: "curve-drag", eventTime: 1, shownAt: 2))
    #expect(CurveEditor.previewMark(reduceMotion: true, hasSamples: true) == "preview-stopped")
    #expect(CurveEditor.previewMark(reduceMotion: false, hasSamples: true) == "preview-playing")
    #expect(CurveEditor.previewMark(reduceMotion: true, hasSamples: false) == nil)
}
