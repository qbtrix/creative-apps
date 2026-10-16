// HaloKeySelectionTests.swift: EZ-2 (#428). The EASING list's segments on
// `keyed`, and picking keys from a row or a timeline diamond; no pick is
// ever a history step. Linux and macOS.
@testable import HaloModel
import Testing

private func keyedSelection() throws -> (project: HaloProject, ball: String, floor: String) {
    let project = commandProject("keyed", .fake)
    let layers = try #require(project.selectedComposition).layers
    let ball = try #require(layers.first { $0.name == "Ball" }).id
    let floor = try #require(layers.first { $0.name == "Floor" }).id
    return (project, ball, floor)
}

@Test func ballListsOneSegmentPerKeyPairInPropertyOrder() throws {
    var (project, ball, floor) = try keyedSelection()
    #expect(project.keySegments.isEmpty)
    project.selectLayer(ball)
    #expect(project.keySegments.map(\.title) == ["Position X 0 → 24", "Opacity 0 → 12"])
    #expect(project.keySegments.map(\.easingTitle) == ["Linear", "Linear"])
    #expect(project.keySegments.map(\.endFrame) == [24, 12])
    #expect(project.keySegments.allSatisfy { $0.preset == .linear && !$0.isPicked })
    project.selectLayer(floor)
    #expect(project.keySegments.isEmpty)
}

@Test func shiftTogglesAKeyInThePick() throws {
    var (project, ball, _) = try keyedSelection()
    project.selectLayer(ball)
    let history = project.history
    let x0 = HaloKeyRef(layerID: ball, property: .x, frame: 0)
    let opacity0 = HaloKeyRef(layerID: ball, property: .opacity, frame: 0)
    project.selectKey(x0, extending: false)
    #expect(project.pickedKeys == [x0])
    #expect(project.pickedSegment?.key == x0)
    #expect(project.pickedPreset == .linear)
    project.selectKey(opacity0, extending: true)
    #expect(project.pickedKeys == [x0, opacity0])
    #expect(project.keySegments.filter(\.isPicked).count == 2)
    project.selectKey(x0, extending: true)
    #expect(project.pickedKeys == [opacity0])
    #expect(project.pickedSegment?.key == opacity0)
    project.selectKey(opacity0, extending: false)
    #expect(project.pickedKeys == [opacity0])
    #expect(project.history == history)
}

@Test func aTracksLastKeyCannotBePicked() throws {
    var (project, ball, floor) = try keyedSelection()
    project.selectLayer(ball)
    let x0 = HaloKeyRef(layerID: ball, property: .x, frame: 0)
    project.selectKey(x0, extending: false)
    let before = project
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 24), extending: false)
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 24), extending: true)
    project.selectKey(HaloKeyRef(layerID: floor, property: .x, frame: 0), extending: false)
    #expect(project == before)
}

@Test func aLaneClickPicksEverySegmentStartingThere() throws {
    var (project, ball, _) = try keyedSelection()
    let history = project.history
    project.selectLaneKeys(layerID: ball, frame: 0, extending: false)
    #expect(project.selectedLayerID == ball)
    #expect(
        project.pickedKeys == [
            HaloKeyRef(layerID: ball, property: .x, frame: 0), HaloKeyRef(layerID: ball, property: .opacity, frame: 0),
        ])
    project.selectLaneKeys(layerID: ball, frame: 0, extending: true)
    #expect(project.pickedKeys.count == 2)
    project.selectLaneKeys(layerID: ball, frame: 12, extending: false)
    #expect(project.pickedKeys.isEmpty)
    #expect(project.pickedPreset == nil)
    #expect(project.history == history)
}

@Test func anotherLaneSelectsItsLayerAndStartsOver() throws {
    var (project, ball, floor) = try keyedSelection()
    project.selectLaneKeys(layerID: ball, frame: 0, extending: false)
    project.selectLaneKeys(layerID: floor, frame: 0, extending: true)
    #expect(project.selectedLayerID == floor)
    #expect(project.selectedKeys.isEmpty)
    #expect(project.pickedSegment == nil)
}

@Test func selectingFloorEmptiesThePickedSegment() throws {
    var (project, ball, floor) = try keyedSelection()
    project.selectLayer(ball)
    project.selectKey(HaloKeyRef(layerID: ball, property: .x, frame: 0), extending: false)
    project.selectLayer(floor)
    #expect(project.pickedSegment == nil)
    #expect(project.pickedKeys.isEmpty)
    #expect(project.pickedPreset == nil)
}

@Test func aCustomCurveReadsCustomAndClearPicksNothing() throws {
    var (project, ball, _) = try keyedSelection()
    project.selectLaneKeys(layerID: ball, frame: 0, extending: false)
    let custom = HaloKeySegment(
        key: HaloKeyRef(layerID: ball, property: .x, frame: 0), endFrame: 24,
        easing: .cubicBezier(x1: 0.1, y1: 0.2, x2: 0.3, y2: 0.4), isPicked: true)
    #expect(custom.easingTitle == "Custom")
    #expect(project.pickedPreset == .linear)
    let history = project.history
    let file = project.file
    project.clearKeySelection()
    #expect(project.selectedKeys.isEmpty)
    #expect(project.pickedSegment == nil)
    #expect(project.history == history)
    #expect(project.file == file)
}
