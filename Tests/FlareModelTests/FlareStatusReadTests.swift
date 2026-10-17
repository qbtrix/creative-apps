// FlareStatusReadTests.swift: the status pills (packet inspector-timeline, IT-9). A 1920 × 1080 scene reads 16:9,
// 1080p, 24 fps; `bounce` (550 × 400) reads 11:8 and its size; a measure of 18 at 24 while playing reads "18 fps"
// and dropping, a 60 Hz measure caps at the document rate, and nothing shows while paused; `showcase`'s title
// layer reads "Text not shown (1)".
import FlareCore
@testable import FlareModel
import Testing

private func opened(_ document: Document) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(document)
    return workspace
}

private let hd = Document(scenes: [Scene(id: "scene-1", name: "Scene 1", width: 1920, height: 1080)])

@Test func anHDSceneReadsSixteenByNineTenEightyPAndItsRate() {
    let pills = opened(hd).statusPills(measuredFPS: nil)
    #expect(pills == StatusPills(aspect: "16:9", size: "1080p", fps: "24 fps"))
}

@Test func bounceReadsItsReducedAspectAndSize() {
    let pills = opened(FlareFixtures.bounce).statusPills(measuredFPS: nil)
    #expect(pills == StatusPills(aspect: "11:8", size: "550 × 400", fps: "24 fps"))
}

@Test func aPortraitHDSceneIsNamedByItsShortSide() {
    let portrait = Document(scenes: [Scene(id: "s", name: "S", fps: 30, width: 1080, height: 1920)])
    let pills = opened(portrait).statusPills(measuredFPS: nil)
    #expect(pills.aspect == "9:16" && pills.size == "1080p" && pills.fps == "30 fps")
}

@Test func measuredEighteenAtTwentyFourWhilePlayingIsDropping() {
    var workspace = opened(hd)
    workspace.play()
    let pills = workspace.statusPills(measuredFPS: 18)
    #expect(pills.actualFPS == "18 fps")
    #expect(pills.isDropping)
}

@Test func aSixtyHertzMeasureShowsEveryFrameAndDropsNone() {
    var workspace = opened(hd)
    workspace.play()
    let pills = workspace.statusPills(measuredFPS: 60)
    #expect(pills.actualFPS == "24 fps")
    #expect(!pills.isDropping)
    #expect(workspace.statusPills(measuredFPS: 23.7).isDropping == false)
}

@Test func pausedOrUnmeasuredShowsNoActualRate() {
    var workspace = opened(hd)
    #expect(workspace.statusPills(measuredFPS: 18).actualFPS == nil)
    workspace.play()
    #expect(workspace.statusPills(measuredFPS: nil).actualFPS == nil)
    #expect(workspace.statusPills(measuredFPS: .nan).actualFPS == nil)
    #expect(workspace.statusPills(measuredFPS: .infinity).actualFPS == nil)
}

@Test func showcaseWarnsOfItsHiddenText() {
    #expect(opened(FlareFixtures.showcase).statusPills(measuredFPS: nil).textWarning == "Text not shown (1)")
    #expect(opened(FlareFixtures.bounce).statusPills(measuredFPS: nil).textWarning == nil)
}

@Test func noDocumentAndDegenerateSidesNeverTrap() {
    #expect(FlareWorkspace(services: .fake()).statusPills(measuredFPS: 24).aspect == "–")
    let flat = Document(scenes: [Scene(id: "s", name: "S", width: 0, height: .infinity)])
    let pills = opened(flat).statusPills(measuredFPS: nil)
    #expect(pills.aspect == "–" && pills.size == "0 × 0")
}
