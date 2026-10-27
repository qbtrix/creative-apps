// ViewZoomTests.swift: the suite's one zoom model (SuiteKernel/Zoom/ViewZoom.swift): the 10% to 3200%
// clamp, Zoom In and Zoom Out over the suite's stops and over an app's own table, the fit-or-scale level,
// the fit scale, the anchor that keeps the point under the pointer still, the ⌘ keys, the snap to 100%
// and the percent text.
@testable import SuiteKernel
import Testing

@Test func zoomClampsToTenToThirtyTwoHundredPercent() {
    let steps = ZoomSteps.suite
    #expect(steps.clamped(2) == 2)
    #expect(steps.clamped(0.05) == 0.1)
    #expect(steps.clamped(-1) == 0.1)
    #expect(steps.clamped(50) == 32)
    #expect(steps.clamped(.infinity) == 32)
    #expect(steps.clamped(.nan) == 1)
}

@Test func suiteStepsWalkThroughOneAndAHalfAndStayInRange() {
    let steps = ZoomSteps.suite
    #expect(steps.zoomedIn(from: 1) == 1.5)
    #expect(steps.zoomedIn(from: 1.5) == 2)
    #expect(steps.zoomedOut(from: 1) == 2.0 / 3)
    #expect(steps.zoomedIn(from: 32) == 32)
    // The 5% stop sits below the range, so it clamps.
    #expect(steps.zoomedOut(from: 0.1) == 0.1)
    // Between stops goes to the neighbour; a bad zoom is 100%.
    #expect(steps.zoomedIn(from: 1.4) == 1.5)
    #expect(steps.zoomedOut(from: 5) == 4)
    #expect(steps.zoomedIn(from: .nan) == 1)
    #expect(steps.zoomedOut(from: 0) == 1)
}

@Test func anAppTableStepsItsOwnStops() {
    let flare = ZoomSteps(stops: [0.1, 0.25, 1.0 / 3, 0.5, 2.0 / 3, 1, 2, 3, 4, 6, 8, 12, 16, 32])
    #expect(flare.zoomedIn(from: 1) == 2)
    #expect(flare.zoomedOut(from: 2) == 1)
    // A table that stops short of the range stays put at its ends.
    let loupe = ZoomSteps(stops: [0.125, 0.25, 0.5, 1, 2, 4, 8])
    #expect(loupe.zoomedIn(from: 8) == 8)
    #expect(loupe.zoomedOut(from: 0.125) == 0.125)
    #expect(loupe.zoomedIn(from: 0.7) == 1)
}

@Test func aLevelDrawsAtTheFitOneHundredPercentOrItsScale() {
    #expect(ZoomLevel.fit.scale(fit: 0.4) == 0.4)
    #expect(ZoomLevel.actual.scale(fit: 0.4) == 1)
    #expect(ZoomLevel.scale(3).scale(fit: 0.4) == 3)
    // A fit or scale that isn't a positive finite number never becomes the zoom.
    #expect(ZoomLevel.fit.scale(fit: .nan) == 1)
    #expect(ZoomLevel.scale(-2).scale(fit: 0.4) == 0.4)
    #expect(ZoomLevel(scale: 1) == .actual)
    #expect(ZoomLevel(scale: 2) == .scale(2))
}

@Test func theFitScaleFitsInsideTheInsetAndNeverPastOneHundredPercent() {
    // 1000 x 600 of room inside a 32-point inset.
    #expect(ZoomSteps.fitScale(width: 2000, height: 500, inWidth: 1064, height: 664, inset: 32) == 0.5)
    #expect(ZoomSteps.fitScale(width: 500, height: 2000, inWidth: 1064, height: 664, inset: 32) == 0.3)
    #expect(ZoomSteps.fitScale(width: 10, height: 10, inWidth: 1064, height: 664, inset: 32) == 1)
    #expect(ZoomSteps.fitScale(width: 800, height: 600, inWidth: 40, height: 40, inset: 32) == 0)
    // A side of 0 or less counts as 1 point.
    #expect(ZoomSteps.fitScale(width: 0, height: -5, inWidth: 1064, height: 664, inset: 32) == 1)
}

@Test func theAnchorKeepsThePointUnderThePointerStill() {
    let steps = ZoomSteps.suite
    let pointer = Point(x: 300, y: 200), origin = Point(x: 100, y: 50)
    let next = steps.anchoredOrigin(pointer: pointer, origin: origin, from: 1, to: 2)
    // The document point under the pointer, (200, 150) at 100%, is still under it at 200%.
    #expect((pointer.x - next.x) / 2 == 200 && (pointer.y - next.y) / 2 == 150)
    // Held at a range end, the origin stays where it was.
    #expect(steps.anchoredOrigin(pointer: pointer, origin: origin, from: 32, to: 64) == origin)
}

@Test func theCommandKeysAskForInOutFitAndActualSize() {
    #expect(ZoomKey("=", command: true) == .zoomIn)
    #expect(ZoomKey("+", command: true) == .zoomIn)
    #expect(ZoomKey("-", command: true) == .zoomOut)
    #expect(ZoomKey("0", command: true) == .fit)
    #expect(ZoomKey("1", command: true) == .actualSize)
    #expect(ZoomKey("1", command: false) == nil)
    #expect(ZoomKey("1", command: true, option: true) == nil)
    #expect(ZoomKey("0", command: true, control: true) == nil)
    #expect(ZoomKey("2", command: true) == nil)
}

@Test func aKeyMovesTheLevel() {
    let steps = ZoomSteps.suite
    #expect(ZoomKey.zoomIn.level(from: 1, steps: steps) == .scale(1.5))
    #expect(ZoomKey.zoomOut.level(from: 1.5, steps: steps) == .actual)
    #expect(ZoomKey.fit.level(from: 3, steps: steps) == .fit)
    #expect(ZoomKey.actualSize.level(from: 3, steps: steps) == .actual)
}

@Test func aPinchNearOneHundredPercentSnapsToIt() {
    let steps = ZoomSteps.suite
    #expect(steps.snapped(0.97) == 1)
    #expect(steps.snapped(1.03) == 1)
    #expect(steps.snapped(0.95) == 0.95)
    #expect(steps.snapped(1.05) == 1.05)
    #expect(steps.snapped(40) == 32)
}

@Test func thePercentTextIsAWholePercent() {
    #expect(ZoomSteps.percentText(0.505) == "51%")
    #expect(ZoomSteps.percentText(2) == "200%")
    #expect(ZoomSteps.percentText(.nan) == "–")
    #expect(ZoomSteps.percentText(0) == "–")
    #expect(ZoomSteps.percentText(1e9) == "1000000%")
}
