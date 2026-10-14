// PropertyScrubUndoTests.swift: #574, QB-F3. Each property scrub is its own "Set Keyframe" step, even when the
// previous scrub ended on the value it started from.
import FlareCore
@testable import FlareModel
import Testing

@Test func aScrubThatEndsOnItsStartValueDoesNotSwallowTheNextScrub() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    w.selectLayer("shadow")
    let start = w.animatedProperties.first { $0.name == "x" }?.value ?? 0
    // Scrub 1: X out and back to where it began.
    for v in [10.0, 20, 30, 20, start] { w.setProperty("x", to: v, dragStart: start) }
    w.endPropertyScrub()
    let afterFirst = w.document
    // Scrub 2: a new gesture from the same start value.
    for v in [10.0, 50] { w.setProperty("x", to: v, dragStart: start) }
    w.endPropertyScrub()
    #expect(w.animatedProperties.first { $0.name == "x" }?.value == 50)

    var count = w, steps = 0
    while count.canUndo { count.undo(); steps += 1 }
    #expect(steps == 2)

    w.undo()
    #expect(w.document == afterFirst && w.canUndo && w.undoActionName == "Undo Set Keyframe")
}
