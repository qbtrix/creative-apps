// HaloKeySelectionTests.swift: EZ-2 (#428). The EASING list's segments on
// `keyed`, and picking keys from a row or a timeline diamond; no pick is
// ever a history step. Key editing (KE-3): picks on `parented` span layers,
// ⌘-click toggles, Select All Keys takes every layer, and stale keys drop
// (#2763). Linux and macOS.
@testable import HaloModel
import SuiteKernel
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
    #expect(project.keySegments.map(\.title) == ["Position X, frames 0–24", "Opacity, frames 0–12"])
    #expect(project.keySegments.allSatisfy { $0.title.contains("frames") })
    #expect(
        project.keySegments.map(\.help) == [
            "Eases Position X between its keys at frames 0 and 24.",
            "Eases Opacity between its keys at frames 0 and 12.",
        ])
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

/// B2: every diamond picks something. Ball's x keys are 0 and 24, its
/// opacity keys 0 and 12; a diamond picks the segments its key starts or ends.
@Test func everyDiamondPicksTheSegmentsItStartsOrEnds() throws {
    var (project, ball, _) = try keyedSelection()
    let history = project.history
    let x0 = HaloKeyRef(layerID: ball, property: .x, frame: 0)
    let opacity0 = HaloKeyRef(layerID: ball, property: .opacity, frame: 0)
    project.selectLaneKeys(layerID: ball, frame: 0, extending: false)
    #expect(project.selectedLayerID == ball)
    #expect(project.pickedKeys == [x0, opacity0])
    project.selectLaneKeys(layerID: ball, frame: 0, extending: true)
    #expect(project.pickedKeys.count == 2)
    project.selectLaneKeys(layerID: ball, frame: 12, extending: false)
    #expect(project.pickedKeys == [opacity0])
    #expect(project.pickedPreset == .linear)
    project.selectLaneKeys(layerID: ball, frame: 24, extending: false)
    #expect(project.pickedKeys == [x0])
    #expect(project.keySegments.map(\.isPicked) == [true, false])
    project.selectLaneKeys(layerID: ball, frame: 12, extending: true)
    #expect(project.pickedKeys == [x0, opacity0])
    project.selectLaneKeys(layerID: ball, frame: 5, extending: false)
    #expect(project.pickedKeys.isEmpty)
    #expect(project.history == history)
}

/// A key between two others picks the segment it starts, and an EASING row
/// pick of that segment doesn't also pick the one before it.
@Test func aMiddleDiamondPicksTheSegmentItStarts() throws {
    var (project, ball, _) = try keyedSelection()
    project.selectLayer(ball)
    project.scrub(to: 12)
    project.setProperty(.x, to: 500)
    #expect(project.selectedLayer?.tracks["x"]?.map(\.frame) == [0, 12, 24])
    let x12 = HaloKeyRef(layerID: ball, property: .x, frame: 12)
    project.selectLaneKeys(layerID: ball, frame: 12, extending: false)
    #expect(project.pickedKeys == [x12, HaloKeyRef(layerID: ball, property: .opacity, frame: 0)])
    project.selectKey(x12, extending: false)
    #expect(project.keySegments.filter(\.isPicked).map(\.key) == [x12])
}

/// The strip's lane tap also selects the diamond's layer; in either order the pick holds.
@Test func aDiamondsLaneTapKeepsThePick() throws {
    var (project, ball, floor) = try keyedSelection()
    project.selectLaneKeys(layerID: ball, frame: 24, extending: false)
    project.selectLayer(ball)
    #expect(project.pickedKeys == [HaloKeyRef(layerID: ball, property: .x, frame: 0)])
    project.selectLayer(floor)
    project.selectLayer(ball)
    project.selectLaneKeys(layerID: ball, frame: 12, extending: false)
    #expect(project.pickedKeys == [HaloKeyRef(layerID: ball, property: .opacity, frame: 0)])
}

/// B1: with keys picked, ⌫ deletes those keys as one step, never the layer.
@Test func deleteRemovesThePickedKeysAsOneStep() throws {
    var (project, ball, floor) = try keyedSelection()
    #expect(project.deleteCommand == .deleteLayer)
    project.selectLaneKeys(layerID: ball, frame: 24, extending: false)
    #expect(project.deleteCommand == .deleteKeys)
    let layers = project.selectedComposition?.layers.count
    let steps = project.history.undo.count
    project.deleteKeys()
    #expect(project.selectedComposition?.layers.count == layers)
    #expect(project.selectedLayerID == ball)
    #expect(project.selectedLayer?.tracks["x"]?.contains { $0.frame == 24 } == false)
    #expect(project.selectedLayer?.tracks["opacity"]?.map(\.frame) == [0, 12])
    #expect(project.selectedLayer?.keyFrames == [0, 12])
    #expect(project.history.undo.count == steps + 1)
    #expect(project.title(for: .undo) == "Undo Delete Keyframes")
    #expect(project.file.unsaved)
    #expect(project.selectedKeys.isEmpty)
    #expect(project.deleteCommand == .deleteLayer)
    project.undo()
    #expect(project.selectedLayer?.keyFrames == [0, 12, 24])
    project.selectLaneKeys(layerID: ball, frame: 24, extending: false)
    project.selectLayer(floor)
    #expect(project.deleteCommand == .deleteKeys)  // KE-3: a pick keeps other layers' keys
    project.pickLaneKeys(layerID: floor, frame: nil, mode: .replace)
    #expect(project.deleteCommand == .deleteLayer)
}

/// Both keys of a track go in one step, whatever order they were picked
/// in, and leave the track static at its first key's value.
@Test func deletingAWholeTrackIsOneStep() throws {
    for order in [[0, 24], [24, 0]] {
        var (project, ball, _) = try keyedSelection()
        project.selectLaneKeys(layerID: ball, frame: order[0], extending: false)
        project.selectLaneKeys(layerID: ball, frame: order[1], extending: true)
        let steps = project.history.undo.count
        project.deleteKeys()
        #expect(project.history.undo.count == steps + 1)
        #expect(project.selectedLayer?.tracks["x"]?.map(\.value) == [160])
        #expect(project.selectedLayer?.tracks["opacity"] == nil)
        #expect(project.selectedLayer?.opacity == 1)
    }
}

/// Nothing picked: no step, no change.
@Test func deleteWithNothingPickedDoesNothing() throws {
    var (project, ball, _) = try keyedSelection()
    project.selectLayer(ball)
    let before = project
    project.deleteKeys()
    #expect(project == before)
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

// MARK: Key editing (KE-3)

/// `parented`: Ball (x at 0 and 24, opacity at 0 and 12) and the Rig null (x at 0 and 47).
private func parentedSelection() throws -> (project: HaloProject, ball: String, rig: String) {
    let project = commandProject("parented", .fake)
    let layers = try #require(project.selectedComposition).layers
    let ball = try #require(layers.first { $0.name == "Ball" }).id
    let rig = try #require(layers.first { $0.name == "Rig" }).id
    return (project, ball, rig)
}

private func key(_ layerID: String, _ property: HaloProperty, _ frame: Int) -> HaloKeyRef {
    HaloKeyRef(layerID: layerID, property: property, frame: frame)
}

/// A Shift-click on another layer keeps the first layer's keys and the
/// selected layer; easing still reads the selected layer only. A plain click
/// there starts over and selects that layer; a bed press clears.
@Test func shiftKeepsOtherLayer() throws {
    var (project, ball, rig) = try parentedSelection()
    let history = project.history
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
    #expect(project.selectedLayerID == ball)
    #expect(project.selectedKeys == [key(ball, .x, 0), key(ball, .opacity, 0), key(rig, .x, 0)])
    #expect(project.pickedFrames(of: ball) == [0] && project.pickedFrames(of: rig) == [0])
    #expect(project.pickedKeys == [key(ball, .x, 0), key(ball, .opacity, 0)])
    project.pickLaneKeys(layerID: rig, frame: 47, mode: .replace)
    #expect(project.selectedLayerID == rig)
    #expect(project.selectedKeys == [key(rig, .x, 47)])
    project.pickLaneKeys(layerID: ball, frame: 12, mode: .extend)
    #expect(project.selectedLayerID == rig)
    #expect(project.pickedFrames(of: ball) == [12])
    project.pickLaneKeys(layerID: rig, frame: nil, mode: .extend)
    #expect(project.selectedKeys.isEmpty)
    #expect(project.history == history)
}

/// ⌘-click adds a lane's keys at a frame, and takes them out once all are picked.
@Test func toggleRemoves() throws {
    var (project, ball, rig) = try parentedSelection()
    project.pickLaneKeys(layerID: ball, frame: 12, mode: .replace)
    project.pickLaneKeys(layerID: rig, frame: 0, mode: .toggle)
    #expect(project.selectedKeys == [key(ball, .opacity, 12), key(rig, .x, 0)])
    project.pickLaneKeys(layerID: ball, frame: 12, mode: .toggle)
    #expect(project.selectedKeys == [key(rig, .x, 0)])
    project.pickLaneKeys(layerID: rig, frame: 0, mode: .toggle)
    #expect(project.selectedKeys.isEmpty)
    #expect(project.selectedLayerID == ball)
}

/// ⌘A on `parented` with Rig hidden (Halo has no eye yet, so hidden is out
/// of its range at the playhead) picks every key, Rig's included, and is no step.
@Test func selectAllTakesHiddenLayers() throws {
    var (project, ball, rig) = try parentedSelection()
    let c = try #require(project.document.compositions.firstIndex { $0.id == project.selectedCompositionID })
    let r = try #require(project.document.compositions[c].layers.firstIndex { $0.id == rig })
    project.document.compositions[c].layers[r].inFrame = 30
    #expect(project.selectedComposition?.layers[r].isVisible(at: project.selectedComposition?.playheadFrame ?? 0) == false)
    project.selectLayer(ball)
    let history = project.history
    #expect(project.selectAllKeysHelp == nil)
    project.selectAllKeys()
    #expect(project.pickedFrames(of: ball) == [0, 12, 24])
    #expect(project.pickedFrames(of: rig) == [0, 47])
    #expect(project.selectedKeys.count == 6 && project.pickedKeyframes.count == 6)
    #expect(project.pickedKeys == [key(ball, .x, 0), key(ball, .opacity, 0)])
    #expect(project.selectedLayerID == ball && project.history == history)
    project.deleteKeys()
    #expect(project.selectedComposition?.layers.allSatisfy { $0.tracks.values.allSatisfy { $0.count < 2 } } == true)
    #expect(project.history.undo.count == 1)
    var empty = commandProject("three-layers", .fake)
    #expect(empty.selectAllKeysHelp == "There are no keys to select.")
    empty.selectAllKeys()
    #expect(empty.selectedKeys.isEmpty)
}

/// #2763: after a Shift-pick, `selectedKeys` holds exactly the live picked
/// keys. A lane pick drops a key an undo took away and keeps other layers';
/// the EASING row and lane-diamond picks still narrow to the selected layer.
@Test func staleKeysDropAfterAShiftPick() throws {
    var (project, ball, rig) = try parentedSelection()
    project.selectLayer(ball)
    project.scrub(to: 12)
    project.setProperty(.x, to: 500)
    project.pickLaneKeys(layerID: ball, frame: 12, mode: .replace)
    project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
    project.undo()
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .extend)
    #expect(project.selectedKeys == [key(ball, .opacity, 12), key(rig, .x, 0), key(ball, .x, 0), key(ball, .opacity, 0)])
    project.selectLaneKeys(layerID: rig, frame: 0, extending: false)
    project.selectLayer(ball)
    project.selectLaneKeys(layerID: ball, frame: 0, extending: true)
    #expect(project.selectedKeys == [key(ball, .x, 0), key(ball, .opacity, 0)])
    project.selectLayer(rig)
    project.selectKey(key(rig, .x, 0), extending: false)
    project.selectLayer(ball)
    project.selectKey(key(ball, .opacity, 0), extending: true)
    #expect(project.selectedKeys == [key(ball, .opacity, 0)])
    project.selectLaneKeys(layerID: ball, frame: 24, extending: false)
    project.selectKey(key(ball, .opacity, 0), extending: true)
    #expect(project.selectedKeys == [key(ball, .x, 0), key(ball, .opacity, 0)])
}
