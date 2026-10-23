// HaloKernelLayersTests.swift: AL-h1, Halo's layer list on SuiteKernel's
// LayerTree. The tree runs back to front with each node following its
// layer's parentID; moves, bring/send, duplicate and the parent picker give
// what the kernel gives, and a kernel refusal is Halo's refusal, recording
// nothing. Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

/// The four-layer fixture with `change` applied, the layer named `select` selected.
private func project(select: String = "Badge", _ change: (inout HaloComposition) -> Void = { _ in }) throws
    -> HaloProject
{
    var state = try #require(HaloFixtures.project("three-layers"))
    change(&state.compositions[0])
    var project = HaloProject(services: .fake)
    project.restore(state)
    project.selectLayer(try #require(project.selectedComposition?.layers.first { $0.name == select }).id)
    return project
}

private func comp(_ p: HaloProject) throws -> HaloComposition { try #require(p.selectedComposition) }

@Test func theTreeRunsBackToFrontAndFollowsParentID() throws {
    let p = try project { $0.layers[0].parentID = $0.layers[3].id }
    let c = try comp(p)
    let tree = c.layerTree
    #expect(tree.roots.map(\.id) == c.layers.reversed().map(\.id))
    #expect(tree.node(c.layers[0].id)?.followsID == c.layers[3].id)
    #expect(HaloComposition.layers(of: tree) == c.layers)
}

@Test func everyMoveMatchesTheKernelsMove() throws {
    let start = try comp(try project())
    for layer in start.layers {
        for index in -1...start.layers.count + 1 {
            var p = try project()
            p.moveLayer(layer.id, to: index)
            var tree = start.layerTree
            let last = start.layers.count - 1
            try tree.move(layer.id, into: nil, at: last - min(max(index, 0), last))
            #expect(try comp(p).layers == HaloComposition.layers(of: tree))
            #expect(try comp(p).layers.firstIndex { $0.id == layer.id } == min(max(index, 0), last))
            #expect((p.undoTitle == nil) == (try comp(p).layers == start.layers))
        }
    }
}

@Test func bringAndSendMatchTheKernelsArrange() throws {
    for (name, step) in [("Badge", ArrangeStep.bringForward), ("Badge", .sendBackward), ("Title", .bringForward)] {
        var p = try project(select: name)
        let start = try comp(p)
        let id = try #require(p.selectedLayerID)
        if step == .bringForward { p.bringSelectedLayerForward() } else { p.sendSelectedLayerBackward() }
        var tree = start.layerTree
        try tree.arrange(step, [id])
        #expect(try comp(p).layers == HaloComposition.layers(of: tree))
    }
}

@Test func duplicateIsTheKernelsCopyUnderAFreshID() throws {
    var p = try project { $0.layers[1].parentID = $0.layers[3].id }
    let source = try #require(p.selectedLayer)
    p.duplicateSelectedLayer()
    let copy = try #require(p.selectedLayer)
    #expect(copy.id != source.id)
    #expect(try comp(p).layers.filter { $0.id == source.id }.count == 1)
    #expect(copy.parentID == source.parentID)
    #expect(copy.withID(source.id) == { var s = source; s.name = "\(source.name) copy"; return s }())
}

@Test func aKernelRefusalIsHaloRefusalAndRecordsNothing() throws {
    var p = try project()
    let before = p.document
    p.moveLayer("no-such-layer", to: 0)
    #expect(p.refusal?.message == HaloEditError.unknownLayer("no-such-layer").message)
    #expect(p.document == before)
    var c = try comp(p)
    #expect(throws: HaloEditError.unknownLayer("nope")) {
        try c.editLayerTree { (tree: inout LayerTree<HaloLayer>) throws(TreeRefusal) in throw .unknown("nope") }
    }
    #expect(c == (try comp(p)))
}

@Test func setParentKeepsTheAnchorOnScreenThroughSetFollow() throws {
    var c = try comp(try project { comp in
        comp.layers[3].tracks["x"] = [HaloKeyframe(frame: 0, value: 300)]
        comp.layers[3].tracks["rotation"] = [HaloKeyframe(frame: 0, value: 90)]
        comp.layers[1].tracks["x"] = [HaloKeyframe(frame: 0, value: 40)]
        comp.layers[1].tracks["y"] = [HaloKeyframe(frame: 0, value: 70)]
    })
    let child = c.layers[1].id, parent = c.layers[3].id
    let screen = try #require(HaloKeyRules.worldMatrix(of: child, in: c, at: 0))
    try HaloKeyRules.setParent(parent, of: child, at: 0, in: &c)
    #expect(c.layerTree.node(child)?.followsID == parent)
    #expect(HaloKeyRules.follows(child, parent, in: c))
    let world = try #require(HaloKeyRules.worldMatrix(of: child, in: c, at: 0))
    let local = c.layerTree.worldPlacement(of: child) { HaloKeyRules.localMatrix(of: $0.payload, in: c, at: 0) }
    #expect(world == local)
    let ball = c.layers[1]
    let anchor = HaloPoint(
        x: HaloKeyRules.value(.anchorX, of: ball, in: c, at: 0), y: HaloKeyRules.value(.anchorY, of: ball, in: c, at: 0))
    #expect(abs(world.apply(anchor).x - screen.apply(anchor).x) < 1e-6)
    #expect(abs(world.apply(anchor).y - screen.apply(anchor).y) < 1e-6)
    #expect(abs(HaloKeyRules.value(.x, of: c.layers[1], in: c, at: 0) - 40) > 1)
    #expect(throws: HaloEditError.parentCycle(c.layers[3].name)) {
        try HaloKeyRules.setParent(child, of: parent, at: 0, in: &c)
    }
}
