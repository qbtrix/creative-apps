// FlareTimelineReadTests.swift: the timeline's read model on FlareWorkspace (draw-key-save DK-5): its rows come from
// `services.keyframes` for the edited owner, an empty owner shows the empty text, and the selected layer names its row.
import FlareCore
@testable import FlareModel
import Testing

/// A workspace on the fakes with `document` open.
private func open(_ document: Document) -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    return w
}

@Test func bounceGivesThreeRowsWithBallsKeys() throws {
    let w = open(FlareFixtures.bounce)
    #expect(w.timelineRows.map(\.layerID) == ["background", "shadow", "ball"])
    #expect(w.timelineRows == FakeKeyframes().rows(FlareFixtures.bounce, owner: .scene("scene-1")))
    let ball = try #require(w.timelineRows.first { $0.layerID == "ball" })
    #expect(ball.name == "Ball" && ball.keyFrames == [0, 12, 24, 36, 47])
    #expect(w.timelineEmptyText == nil)
}

@Test func emptyGivesNoRowsAndTheEmptyText() {
    let w = open(FlareFixtures.empty)
    #expect(w.timelineRows.isEmpty)
    #expect(w.timelineEmptyText == "No layers yet. Draw on the stage to add one.")
}

@Test func noDocumentGivesNoRows() {
    let w = FlareWorkspace(services: .fake())
    #expect(w.timelineRows.isEmpty && w.selectedTimelineRowID == nil)
}

@Test func selectingBallGivesItsRowID() {
    var w = open(FlareFixtures.bounce)
    #expect(w.selectedTimelineRowID == nil)
    w.selectLayer("ball")
    #expect(w.selectedTimelineRowID == "ball")
    w.selectLayer("shadow")
    #expect(w.selectedTimelineRowID == "shadow")
}

@Test func editingASymbolInPlaceGivesTheSymbolsRows() {
    var w = open(FlareFixtures.character)
    #expect(w.timelineRows.map(\.layerID) == ["legs", "body", "arms", "head"])
    w.editSymbol("wave")
    #expect(w.timelineRows.map(\.layerID) == ["hand"])
    #expect(w.timelineRows.first?.keyFrames == [0, 12, 23])
    w.selectLayer("hand")
    #expect(w.selectedTimelineRowID == "hand")
    w.exitSymbol()
    #expect(w.timelineRows.map(\.layerID) == ["legs", "body", "arms", "head"])
}
