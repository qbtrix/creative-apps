// HaloKeyEditingTests.swift: key-editing's Model walk (MJ-KE) on `parented`.
// A move shifts every picked key on every layer, one drag is one "Move
// Keyframes" step, and a move onto an unpicked key refuses whole. KE-1 writes
// these on the adapter stubs, disabled; KE-4 turns them on with the move
// bodies (`HaloKeyMove+Kernel.swift`). Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

/// `parented` (Ball keyed at 0, 12 and 24; the Rig null at 0 and 47) with Ball's and Rig's ids.
private func parentedKeys() throws -> (project: HaloProject, ball: String, rig: String) {
    let project = commandProject("parented", .fake)
    let layers = try #require(project.selectedComposition).layers
    let ball = try #require(layers.first { $0.name == "Ball" }).id
    let rig = try #require(layers.first { $0.name == "Rig" }).id
    return (project, ball, rig)
}

/// The frames of `layerID`'s keys on `property`, in track order.
private func frames(_ project: HaloProject, _ layerID: String, _ property: HaloProperty) -> [Int] {
    project.selectedComposition?.layers.first { $0.id == layerID }?.tracks[property.rawValue]?.map(\.frame) ?? []
}

@Test(.disabled("KE-4: the move bodies")) func moveSpansLayers() throws {
    var (project, ball, rig) = try parentedKeys()
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
    project.moveKeys(by: 6, dragStart: 0)
    project.endKeyDrag()
    #expect(frames(project, ball, .x) == [6, 24])
    #expect(frames(project, ball, .opacity) == [6, 12])
    #expect(frames(project, rig, .x) == [6, 47])
    #expect(project.pickedFrames(of: ball) == [6])
    #expect(project.pickedFrames(of: rig) == [6])
}

@Test(.disabled("KE-4: the move bodies")) func oneStepPerDrag() throws {
    var (project, ball, rig) = try parentedKeys()
    let before = project.selectedComposition?.layers
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    project.pickLaneKeys(layerID: rig, frame: 0, mode: .extend)
    for _ in 0..<3 { project.moveKeys(by: 2, dragStart: 0) }
    project.endKeyDrag()
    #expect(frames(project, ball, .x) == [6, 24])
    #expect(frames(project, rig, .x) == [6, 47])
    #expect(project.history.undo.count == 1)
    #expect(project.history.undo.last?.name == "Move Keyframes")
    project.undo()
    #expect(project.selectedComposition?.layers == before)
    #expect(project.history.undo.isEmpty)
}

@Test(.disabled("KE-4: the move bodies")) func collisionRefusesWhole() throws {
    var (project, ball, _) = try parentedKeys()
    let before = project.selectedComposition?.layers
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    project.moveKeys(by: 12, dragStart: 0)
    project.endKeyDrag()
    #expect(project.selectedComposition?.layers == before)
    #expect(project.refusal?.message == "A key is already at frame 12 on Ball.")
    #expect(project.history.undo.isEmpty)
    #expect(project.pickedFrames(of: ball) == [0])
}
