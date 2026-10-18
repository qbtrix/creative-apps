// FlareViewMathTests.swift: stage-edit SE-2 (J14). Zoom In and Zoom Out step through FlareZoom.steps, clamped to
// 10%...3200%; the zoom readout says "Fit" or a whole percent; a guide reads "y 300" or "x 120".
import FlareCore
@testable import FlareModel
import Testing

@Test func zoomInFromOneIsTwoAndOutFromTwoIsOne() {
    #expect(FlareZoom.zoomIn(1) == 2)
    #expect(FlareZoom.zoomIn(FlareZoom.zoomIn(1)) == 3)
    #expect(FlareZoom.zoomOut(2) == 1)
    #expect(FlareZoom.zoomOut(1) == 2.0 / 3)
}

@Test func zoomStepsVisitEveryStepInOrder() {
    var up = [FlareZoom.steps[0]]
    while let last = up.last, last < FlareZoom.range.upperBound { up.append(FlareZoom.zoomIn(last)) }
    #expect(up == FlareZoom.steps)
    var down = [FlareZoom.range.upperBound]
    while let last = down.last, last > FlareZoom.range.lowerBound { down.append(FlareZoom.zoomOut(last)) }
    #expect(down == FlareZoom.steps.reversed())
    #expect(FlareZoom.steps.first == 0.1 && FlareZoom.steps.last == 32)
    #expect(FlareZoom.steps.contains(6) && FlareZoom.steps.contains(8) && !FlareZoom.steps.contains(1.5))
}

@Test func zoomBetweenStepsGoesToTheNeighbouringStep() {
    #expect(FlareZoom.zoomIn(1.4) == 2)
    #expect(FlareZoom.zoomOut(1.4) == 1)
    #expect(FlareZoom.zoomIn(5) == 6)
    #expect(FlareZoom.zoomOut(5) == 4)
}

@Test func zoomIsClampedToTheRange() {
    #expect(FlareZoom.zoomIn(32) == 32)
    #expect(FlareZoom.zoomIn(100) == 32)
    #expect(FlareZoom.zoomOut(0.1) == 0.1)
    #expect(FlareZoom.zoomOut(0.01) == 0.1)
    #expect(FlareZoom.zoomIn(0.01) == 0.1)
    #expect(FlareZoom.zoomOut(100) == 32)
    #expect(FlareZoom.zoomIn(.nan) == 1 && FlareZoom.zoomOut(.infinity) == 1 && FlareZoom.zoomIn(-2) == 1)
}

@Test func zoomReadoutSaysFitOrAWholePercent() {
    #expect(FlareZoom.readout(nil) == "Fit")
    #expect(FlareZoom.readout(2) == "200%")
    #expect(FlareZoom.readout(1) == "100%")
    #expect(FlareZoom.readout(1.0 / 3) == "33%")
    #expect(FlareZoom.readout(32) == "3200%")
    #expect(FlareZoom.readout(.nan) == "–" && FlareZoom.readout(0) == "–")
}

@Test func guideReadoutNamesTheAxisAndPosition() {
    var w = FlareWorkspace(services: .fake())
    #expect(w.guideReadout(at: 0) == nil)
    w.load(FlareFixtures.bounce)
    w.addGuide(.horizontal, at: 300)
    w.addGuide(.vertical, at: 120.4)
    #expect(w.guideReadout(at: 0) == "y 300")
    #expect(w.guideReadout(at: 1) == "x 120")
    #expect(w.guideReadout(at: 2) == nil)
    #expect(w.guideReadout(at: -1) == nil)
}
