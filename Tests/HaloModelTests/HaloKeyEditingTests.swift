// HaloKeyEditingTests.swift: key-editing's Model walk (MJ-KE) on `parented`.
// A move shifts every picked key on every layer, one drag is one "Move
// Keyframes" step, and a move onto an unpicked key refuses whole. KE-1 wrote
// these on the adapter stubs, disabled; KE-4 turns them on with the move
// bodies (`HaloKeyMove+Kernel.swift`). A pick on a second layer joins through
// the kernel `Selection` here (`pickAlso`), since cross-layer Shift-picks are
// KE-3's; the picks are read from `selectedKeys`, which every layer shares.
// Linux and macOS.
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

/// Adds `layerID`'s x key at `frame` to the pick, whatever layer is selected.
private func pickAlso(_ project: inout HaloProject, _ layerID: String, _ frame: Int) {
    project.keySelection.pick(HaloKeyRef(layerID: layerID, property: .x, frame: frame), .extend)
}

/// The picked frames on `layerID`, read from the pick every layer shares.
private func picked(_ project: HaloProject, _ layerID: String) -> Set<Int> {
    Set(project.selectedKeys.filter { $0.layerID == layerID }.map(\.frame))
}

@Test func moveSpansLayers() throws {
    var (project, ball, rig) = try parentedKeys()
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    pickAlso(&project, rig, 0)
    #expect(project.moveKeysHelp == nil)
    project.moveKeys(by: 6, dragStart: 0)
    project.endKeyDrag()
    #expect(frames(project, ball, .x) == [6, 24])
    #expect(frames(project, ball, .opacity) == [6, 12])
    #expect(frames(project, rig, .x) == [6, 47])
    #expect(project.pickedFrames(of: ball) == [6])
    #expect(picked(project, rig) == [6])
    #expect(project.history.undo.last?.name == "Move Keyframes")
}

@Test func oneStepPerDrag() throws {
    var (project, ball, rig) = try parentedKeys()
    let before = project.selectedComposition?.layers
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    pickAlso(&project, rig, 0)
    for _ in 0..<3 { project.moveKeys(by: 2, dragStart: 0) }
    project.endKeyDrag()
    #expect(project.keyDragSerial == 1)
    project.moveKeys(by: 1, dragStart: 6)
    project.endKeyDrag()
    #expect(project.history.undo.count == 2)
    project.undo()
    #expect(frames(project, ball, .x) == [6, 24])
    #expect(frames(project, rig, .x) == [6, 47])
    #expect(project.history.undo.count == 1)
    #expect(project.history.undo.last?.name == "Move Keyframes")
    project.undo()
    #expect(project.selectedComposition?.layers == before)
    #expect(project.history.undo.isEmpty)
}

@Test func collisionRefusesWhole() throws {
    var (project, ball, rig) = try parentedKeys()
    let before = project.selectedComposition?.layers
    project.pickLaneKeys(layerID: ball, frame: 0, mode: .replace)
    pickAlso(&project, rig, 0)
    project.moveKeys(by: 12, dragStart: 0)
    project.endKeyDrag()
    #expect(project.selectedComposition?.layers == before)
    #expect(project.refusal?.message == "A key is already at frame 12 on Ball.")
    #expect(project.history.undo.isEmpty)
    #expect(project.pickedFrames(of: ball) == [0])
    #expect(picked(project, rig) == [0])
}

@Test func nothingPickedSaysWhyAndMovesNothing() throws {
    var (project, _, _) = try parentedKeys()
    let before = project
    #expect(project.moveKeysHelp == "Select keyframes to move.")
    project.moveKeys(by: 6, dragStart: 0)
    project.endKeyDrag()
    #expect(project.document == before.document && project.history.undo.isEmpty)
}

@Test func pastTheEndRefusesWhole() throws {
    var (project, _, rig) = try parentedKeys()
    let before = project.selectedComposition?.layers
    project.pickLaneKeys(layerID: rig, frame: 47, mode: .replace)
    project.moveKeys(by: 1, dragStart: 47)
    #expect(project.selectedComposition?.layers == before)
    #expect(project.refusal?.message == "A key can't move past frame 47.")
    #expect(project.history.undo.isEmpty)
}

/// MJ-KE step 7 (#5949): after Select All Keys and ⌫, no lane draws a key. A
/// track left with one key is static, so its leftover value is no diamond.
@Test func deletingEveryKeyLeavesNoDiamond() throws {
    var (project, ball, rig) = try parentedKeys()
    project.selectAllKeys()
    #expect(project.deleteCommand == .deleteKeys)
    project.deleteKeys()
    #expect(project.timelineRows.allSatisfy { $0.keyFrames.isEmpty })
    #expect(project.pickedFrames(of: ball).isEmpty && project.pickedFrames(of: rig).isEmpty)
    project.undo()
    let rows = Dictionary(uniqueKeysWithValues: project.timelineRows.map { ($0.id, $0.keyFrames) })
    #expect(rows[ball] == [0, 12, 24] && rows[rig] == [0, 47])
}
