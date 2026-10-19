// FlareLayersKernelTests.swift: the shared layers list's reorder drop on Flare (adopt-kernel-layers AL-f3).
// LayerTreeList.reorder proposes the layer and its kernel index among the roots, counted from the back once the
// layer leaves; `layerMove` maps that onto moveLayer's top-first offsets. Runs on Linux and macOS.
import FlareModel
import Testing

/// The bounce fixture: Ball, Shadow, Background, top first.
private func bounce() -> FlareWorkspace {
    FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
}

@Test func aDropAboveTheTopRowMovesTheBottomLayerToTheTop() throws {
    var workspace = bounce()
    #expect(workspace.layerRows.map(\.id) == ["ball", "shadow", "background"])
    // Background dropped above Ball: the siblings left are Ball and Shadow, so the kernel index is 2.
    let move = try #require(workspace.layerMove("background", parent: nil, index: 2))
    #expect(move.from == 2 && move.to == 0)
    workspace.moveLayer(from: move.from, to: move.to)
    #expect(workspace.layerRows.map(\.id) == ["background", "ball", "shadow"])
}

@Test func aDropBelowTheNextRowMovesTheLayerDownOne() throws {
    var workspace = bounce()
    // Ball dropped below Shadow: Shadow and Background are left, so Ball lands one from the back.
    let move = try #require(workspace.layerMove("ball", parent: nil, index: 1))
    #expect(move.from == 0 && move.to == 2)
    workspace.moveLayer(from: move.from, to: move.to)
    #expect(workspace.layerRows.map(\.id) == ["shadow", "ball", "background"])
    #expect(workspace.layerError == nil)
}

@Test func aDropIntoALayerAnUnknownLayerOrAnIndexPastTheRootsMapsToNothing() {
    let workspace = bounce()
    #expect(workspace.layerMove("ball", parent: "shadow", index: 0) == nil)
    #expect(workspace.layerMove("ghost", parent: nil, index: 0) == nil)
    #expect(workspace.layerMove("ball", parent: nil, index: 3) == nil)
    #expect(workspace.layerMove("ball", parent: nil, index: -1) == nil)
}
