// FlareGuideDragTests.swift: stage-edit SE-2 (J14, QB-F3). A guide drag shows its guide moving and sends its view
// intents on release, one undo step: a drag out of a ruler adds a guide, a drag of a guide moves it, and either
// released over its ruler leaves no guide. Positions snap to whole scene points.
import FlareCore
@testable import FlareModel
import Testing

/// Applies the guide intents a release sends, as the window's router does.
private func apply(_ intents: [FlareIntent], to w: inout FlareWorkspace) {
    for case .view(let intent) in intents {
        switch intent {
        case .addGuide(let horizontal, let at): w.addGuide(horizontal ? .horizontal : .vertical, at: at)
        case .moveGuide(let index, let to, let start): w.moveGuide(at: index, to: to, dragStart: start)
        case .endGuideDrag: w.endGuideDrag()
        case .removeGuide(let index): w.removeGuide(at: index)
        default: Issue.record("a guide drag sent \(intent)")
        }
    }
}

private func bounce() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.bounce)
    return w
}

@Test func aDragOutOfTheTopRulerAddsOneGuideOnRelease() {
    var w = bounce()
    var drag = FlareGuideDrag(axis: .horizontal, at: 12.4)
    for y in [120.0, 260.2, 299.6] { drag.move(to: y) }
    #expect(drag.shown(over: w.guides) == [Guide(axis: .horizontal, position: 300)])
    #expect(w.guides.isEmpty, "the drag changed the document before its release")
    apply(drag.end(overRuler: false), to: &w)
    #expect(w.guides == [Guide(axis: .horizontal, position: 300)] && w.guideReadout(at: 0) == "y 300")
    w.undo()
    #expect(w.guides.isEmpty)
}

@Test func aGuideDragIsOneMoveGuideStep() throws {
    var w = bounce()
    w.addGuide(.vertical, at: 40)
    w.addGuide(.horizontal, at: 300)
    let added = w.document
    var drag = try #require(FlareGuideDrag(guide: 1, of: w.guides))
    for y in [305.0, 312, 320.3] { drag.move(to: y) }
    #expect(drag.shown(over: w.guides) == [Guide(axis: .vertical, position: 40), Guide(axis: .horizontal, position: 320)])
    apply(drag.end(overRuler: false), to: &w)
    #expect(w.guideReadout(at: 1) == "y 320" && w.undoActionName == "Undo Move Guide")
    let moved = w.document
    var again = try #require(FlareGuideDrag(guide: 1, of: w.guides))
    again.move(to: 340)
    apply(again.end(overRuler: false), to: &w)
    w.undo()
    #expect(w.document == moved, "a second guide drag joined the first one's step")
    w.undo()
    #expect(w.document == added && w.undoActionName == "Undo Add Guide")
}

@Test func aGuideDroppedOnItsRulerIsGone() throws {
    var w = bounce()
    w.addGuide(.horizontal, at: 300)
    var drag = try #require(FlareGuideDrag(guide: 0, of: w.guides))
    drag.move(to: -4)
    apply(drag.end(overRuler: true), to: &w)
    #expect(w.guides.isEmpty && w.undoActionName == "Undo Remove Guide")
    var fresh = FlareGuideDrag(axis: .vertical, at: 80)
    fresh.move(to: -3)
    #expect(fresh.end(overRuler: true).isEmpty, "a new guide dropped back on its ruler was placed")
}

@Test func aGuideDragThatGoesNowhereOrNowhereRealSendsNothing() throws {
    var w = bounce()
    w.addGuide(.horizontal, at: 300)
    #expect(FlareGuideDrag(guide: 1, of: w.guides) == nil)
    var drag = try #require(FlareGuideDrag(guide: 0, of: w.guides))
    drag.move(to: .nan)
    #expect(drag.position == 300)
    #expect(drag.end(overRuler: false).isEmpty, "a drag back to where it began made a step")
}
