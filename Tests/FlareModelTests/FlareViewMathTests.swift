// FlareViewMathTests.swift: stage-edit SE-2 (J14). Zoom In and Zoom Out step Flare's stop table on the suite's
// zoom model (FlareWorkspace.zoomSteps, SuiteKernel's ZoomSteps), clamped to
// 10%...3200%; the zoom readout says "Fit" or a whole percent; a guide reads "y 300" or "x 120".
import FlareCore
@testable import FlareModel
import Testing

/// Flare's stop table on the suite's zoom model.
private let steps = FlareWorkspace.zoomSteps

@Test func zoomInFromOneIsTwoAndOutFromTwoIsOne() {
    #expect(steps.zoomedIn(from: 1) == 2)
    #expect(steps.zoomedIn(from: steps.zoomedIn(from: 1)) == 3)
    #expect(steps.zoomedOut(from: 2) == 1)
    #expect(steps.zoomedOut(from: 1) == 2.0 / 3)
}

@Test func zoomStepsVisitEveryStepInOrder() {
    var up = [steps.stops[0]]
    while let last = up.last, last < steps.range.upperBound { up.append(steps.zoomedIn(from: last)) }
    #expect(up == steps.stops)
    var down = [steps.range.upperBound]
    while let last = down.last, last > steps.range.lowerBound { down.append(steps.zoomedOut(from: last)) }
    #expect(down == steps.stops.reversed())
    #expect(steps.stops.first == 0.1 && steps.stops.last == 32)
    #expect(steps.stops.contains(6) && steps.stops.contains(8) && !steps.stops.contains(1.5))
}

@Test func zoomBetweenStepsGoesToTheNeighbouringStep() {
    #expect(steps.zoomedIn(from: 1.4) == 2)
    #expect(steps.zoomedOut(from: 1.4) == 1)
    #expect(steps.zoomedIn(from: 5) == 6)
    #expect(steps.zoomedOut(from: 5) == 4)
}

@Test func zoomIsClampedToTheRange() {
    #expect(steps.zoomedIn(from: 32) == 32)
    #expect(steps.zoomedIn(from: 100) == 32)
    #expect(steps.zoomedOut(from: 0.1) == 0.1)
    #expect(steps.zoomedOut(from: 0.01) == 0.1)
    #expect(steps.zoomedIn(from: 0.01) == 0.1)
    #expect(steps.zoomedOut(from: 100) == 32)
    #expect(steps.zoomedIn(from: .nan) == 1 && steps.zoomedOut(from: .infinity) == 1 && steps.zoomedIn(from: -2) == 1)
}

@Test func zoomReadoutSaysFitOrAWholePercent() {
    #expect(FlareWorkspace.zoomReadout(nil) == "Fit")
    #expect(FlareWorkspace.zoomReadout(2) == "200%")
    #expect(FlareWorkspace.zoomReadout(1) == "100%")
    #expect(FlareWorkspace.zoomReadout(1.0 / 3) == "33%")
    #expect(FlareWorkspace.zoomReadout(32) == "3200%")
    #expect(FlareWorkspace.zoomReadout(.nan) == "–" && FlareWorkspace.zoomReadout(0) == "–")
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
