// HaloTimelineTests.swift: the selected composition's timeline: timecodes at
// 24 and 30 fps, scrubbing clamped to the composition, the layers active at a
// frame, the strip's rows with each layer's key frames, in and out points set
// at the playhead (an out point before the in point is refused), and the
// layer header's frames with the out point exclusive. Runs on Linux and macOS.
@testable import HaloModel
import Testing

/// A 2-second composition at `fps` with a solid selected.
private func project(fps: Int = 24) -> HaloProject {
    var project = HaloProject()
    project.newComposition(CompositionSettings(name: "Comp", framesPerSecond: fps, durationSeconds: 2))
    project.newLayer(.solid)
    return project
}

@Test func timecodeAt24And30fps() throws {
    let at24 = try #require(project(fps: 24).selectedComposition)
    #expect(at24.timecode(0) == "00:00:00:00")
    #expect(at24.timecode(36) == "00:00:01:12")
    #expect(at24.timecode(24 * 3661 + 23) == "01:01:01:23")
    let at30 = try #require(project(fps: 30).selectedComposition)
    #expect(at30.timecode(36) == "00:00:01:06")
    #expect(at30.timecode(30 * 60 + 29) == "00:01:00:29")
    #expect(at30.timecode(-5) == "00:00:00:00")
}

@Test func playheadStartsAtZeroAndTheReadoutFollowsScrubbing() {
    var project = project()
    #expect(project.selectedComposition?.playheadTimecode == "00:00:00:00")
    project.scrub(to: 36)
    #expect(project.selectedComposition?.playheadFrame == 36)
    #expect(project.selectedComposition?.playheadTimecode == "00:00:01:12")
}

@Test func scrubbingClampsToTheCompositionsFramesAndEachKeepsItsOwn() throws {
    var project = project()
    let first = try #require(project.selectedCompositionID)
    project.scrub(to: 48)
    #expect(project.selectedComposition?.playheadFrame == 47)
    project.scrub(to: -1)
    #expect(project.selectedComposition?.playheadFrame == 0)
    project.scrub(to: 12)
    project.newComposition()
    #expect(project.selectedComposition?.playheadFrame == 0)
    project.selectComposition(first)
    #expect(project.selectedComposition?.playheadFrame == 12)
    var empty = HaloProject()
    empty.scrub(to: 10)
    #expect(empty.timelineRows.isEmpty)
}

@Test func layersActiveAtAFrameFollowTheirSpans() throws {
    var project = project()
    var ok = false
    project.scrub(to: 10)
    ok = project.setSelectedLayerInPoint()
    #expect(ok)
    project.newLayer(.text)
    project.scrub(to: 20)
    ok = project.setSelectedLayerOutPoint()
    #expect(ok)
    let comp = try #require(project.selectedComposition)
    #expect(comp.layers(at: 0).map(\.name) == ["Text 1"])
    #expect(comp.layers(at: 15).map(\.name) == ["Text 1", "Solid 1"])
    #expect(comp.layers(at: 20).map(\.name) == ["Text 1", "Solid 1"])
    #expect(comp.layers(at: 21).map(\.name) == ["Solid 1"])
    #expect(comp.layers(at: 48).isEmpty)
}

@Test func inAndOutPointsAreSetAtThePlayhead() {
    var project = project()
    var ok = false
    project.scrub(to: 12)
    ok = project.setSelectedLayerInPoint()
    #expect(ok)
    project.scrub(to: 30)
    ok = project.setSelectedLayerOutPoint()
    #expect(ok)
    #expect(project.selectedLayer?.inFrame == 12)
    #expect(project.selectedLayer?.outFrame == 31)
}

@Test func anOutPointBeforeTheInPointIsRefused() {
    var project = project()
    var ok = false
    project.scrub(to: 20)
    project.setSelectedLayerInPoint()
    project.scrub(to: 19)
    ok = project.setSelectedLayerOutPoint()
    #expect(!ok)
    #expect(project.selectedLayer?.outFrame == 48)
    project.scrub(to: 30)
    project.setSelectedLayerOutPoint()
    project.scrub(to: 31)
    ok = project.setSelectedLayerInPoint()
    #expect(!ok)
    #expect(project.selectedLayer?.inFrame == 20)
    #expect(project.selectedLayer?.outFrame == 31)
}

@Test func inAndOutWithNoSelectedLayerAreRefused() throws {
    var project = project()
    project.newComposition()
    let results = [project.setSelectedLayerInPoint(), project.setSelectedLayerOutPoint()]
    #expect(results == [false, false])
}

@Test func theStripFitsTheWholeComposition() throws {
    let comp = try #require(project().selectedComposition)
    #expect(comp.frameWidth(toFit: 480) == 10)
    #expect(comp.frameWidth(toFit: 0) == 0)
    #expect(comp.frameWidth(toFit: .nan) == 0)
}

@Test func timelineRowsShowEachLayersSpanAndTheSelection() throws {
    var project = project()
    let solid = try #require(project.selectedLayerID)
    project.newLayer(.shape)
    project.scrub(to: 5)
    project.setSelectedLayerInPoint()
    project.selectLayer(solid)
    let rows = project.timelineRows
    #expect(rows.map(\.name) == ["Shape 1", "Solid 1"])
    #expect(rows.map(\.span) == [5...48, 0...48])
    #expect(rows.map(\.isSelected) == [false, true])
}

/// `name` loaded on the fake services, first composition selected.
private func fixture(_ name: String) throws -> HaloProject {
    var project = HaloProject(services: .fake)
    project.restore(try #require(HaloFixtures.project(name)))
    return project
}

@Test func rowsCarryEachLayersKeyFrames() throws {
    let rows = try fixture("keyed").timelineRows
    #expect(rows.map(\.name) == ["Ball", "Floor"])
    #expect(rows.map(\.keyFrames) == [[0, 12, 24], []])
}

@Test func headerReadsFramesWithTheOutPointExclusive() throws {
    var project = try fixture("three-layers")
    project.selectLayer("comp-1-layer-4")
    #expect(project.selectedLayerHeader == HaloLayerHeader(name: "Title", kind: "Text", frames: "Frames 24–71", parent: nil))
    project.selectLayer("comp-1-layer-3")
    project.scrub(to: 20)
    project.setSelectedLayerInPoint()
    project.scrub(to: 50)
    project.setSelectedLayerOutPoint()
    #expect(project.selectedLayerHeader?.frames == "Frames 20–50")
    #expect(project.selectedLayer?.outFrame == 51)
}
