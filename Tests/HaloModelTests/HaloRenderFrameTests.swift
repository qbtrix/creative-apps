// HaloRenderFrameTests.swift: Render Frame (render-out RO-2) on the fakes.
// `parented`: a 480 × 270 frame at the playhead with no undo step; a scrub,
// or an edit, makes it stale and scrubbing back or rendering again makes it
// fresh. `two-comps`: a frame from another composition never shows. Playing
// hides it. `three-layers`: the note is the frame's undrawn-text note.
// Linux and macOS.
@testable import HaloModel
import Testing

private func project(_ fixture: String, services: HaloServices = .fake, at frame: Int = 0) throws -> HaloProject {
    var project = HaloProject(services: services, document: try #require(HaloFixtures.project(fixture)))
    project.scrub(to: frame)
    return project
}

@Test func renderFrameMakesAQuarterSizeFrameAtThePlayheadWithNoUndoStep() throws {
    var p = try project("parented", at: 12)
    let undo = p.history.undo
    p.renderCurrentFrame()
    let frame = try #require(p.shownRenderedFrame)
    #expect(frame.frame == 12)
    #expect(frame.pixels.width == 480 && frame.pixels.height == 270)
    #expect(p.renderedFrame?.source == p.selectedComposition)
    #expect(p.renderedFrameSummary == "Rendered frame 12 at 480 × 270")
    #expect(!p.renderedFrameStale)
    #expect(p.renderedFrameNote == nil)
    #expect(p.history.undo == undo)
    #expect(!p.file.unsaved)
}

@Test func nothingRenderedMeansNothingShownAndNotStale() throws {
    let p = try project("parented", at: 12)
    #expect(p.renderedFrame == nil && p.shownRenderedFrame == nil)
    #expect(!p.renderedFrameStale)
    #expect(p.renderedFrameNote == nil && p.renderedFrameSummary == nil)
}

@Test func renderFrameWithNoCompositionDoesNothing() {
    var p = HaloProject(services: .fake)
    p.renderCurrentFrame()
    #expect(p.renderedFrame == nil && p.renderedFrameSummary == nil)
}

@Test func aScrubMakesItStaleAndScrubbingBackMakesItFresh() throws {
    var p = try project("parented", at: 12)
    p.renderCurrentFrame()
    p.scrub(to: 13)
    #expect(p.renderedFrameStale)
    #expect(p.renderedFrameNote == "Rendered frame is out of date.")
    #expect(p.renderedFrameSummary == "Rendered frame 12 at 480 × 270")
    p.scrub(to: 12)
    #expect(!p.renderedFrameStale)
    #expect(p.renderedFrameNote == nil)
    p.scrub(to: 13)
    p.renderCurrentFrame()
    #expect(!p.renderedFrameStale && p.renderedFrameNote == nil)
    #expect(p.renderedFrameSummary == "Rendered frame 13 at 480 × 270")
}

@Test func anEditMakesItStaleAndRenderingAgainMakesItFresh() throws {
    var p = try project("parented", at: 12)
    p.renderCurrentFrame()
    let ball = try #require(p.selectedComposition?.layers.first { $0.name == "Ball" })
    p.selectLayer(ball.id)
    p.setProperty(.x, to: 500)
    #expect(p.history.undo.count == 1)
    #expect(p.renderedFrameStale)
    #expect(p.renderedFrameNote == "Rendered frame is out of date.")
    p.renderCurrentFrame()
    #expect(!p.renderedFrameStale && p.renderedFrameNote == nil)
    #expect(p.history.undo.count == 1)
    p.undo()
    #expect(p.renderedFrameStale)
}

@Test func aFrameFromAnotherCompositionIsNotShown() throws {
    var p = try project("two-comps")
    let intro = try #require(p.compositions.first { $0.name == "Intro" })
    let outro = try #require(p.compositions.first { $0.name == "Outro" })
    p.selectComposition(intro.id)
    p.renderCurrentFrame()
    #expect(p.shownRenderedFrame != nil)
    p.selectComposition(outro.id)
    #expect(p.shownRenderedFrame == nil)
    #expect(p.renderedFrameNote == nil && p.renderedFrameSummary == nil)
    p.selectComposition(intro.id)
    #expect(p.shownRenderedFrame != nil)
    #expect(!p.renderedFrameStale)
}

@Test func playingHidesTheRenderedFrame() throws {
    var p = try project("parented", at: 12)
    p.renderCurrentFrame()
    p.play(at: 100)
    #expect(p.playback.playing)
    #expect(p.shownRenderedFrame == nil)
    #expect(p.renderedFrameNote == nil && p.renderedFrameSummary == nil)
    p.pause()
    #expect(p.shownRenderedFrame != nil)
}

@Test func withoutARasterizerTheNoteIsTheFramesOwn() throws {
    var services = HaloServices.fake
    services.text = nil
    var p = try project("three-layers", services: services, at: 30)
    p.renderCurrentFrame()
    let note = try #require(p.renderedFrameNote)
    #expect(note == p.renderedFrame?.frame.note)
    #expect(note == "1 text layer not drawn.")
}

@Test func withTheFakeRasterizerThereIsNoNote() throws {
    var p = try project("three-layers", at: 30)
    p.renderCurrentFrame()
    #expect(p.shownRenderedFrame != nil)
    #expect(p.renderedFrameNote == nil)
}
