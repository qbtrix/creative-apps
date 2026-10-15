// LiveStageBudgetTests.swift: ST-10 of live-stage (#798), the stage's quality budgets on the live types, as debug-build
// CI gates: the median of 50 runs, timed with `ContinuousClock`. QB-L5: one `LiveHits.hit` per pointer move within
// 10 ms on `bounce`; QB-L6: one frame's `LiveStage` draw list within 20 ms on `bounce`; QB-L11 (model half): one
// frame's list of a scene with 500 instances nested two deep within 40 ms.
import FlareCore
import FlareModel
import Testing

/// The median of 50 timed runs of `work`, printed with its name.
private func median(_ name: String, _ work: () -> Void) -> Duration {
    let clock = ContinuousClock()
    let runs = (0..<50).map { _ in clock.measure(work) }.sorted()
    print("LiveStageBudget \(name) median \(runs[25]) slowest \(runs[49])")
    return runs[25]
}

@Test func hitWithinBudget() {
    let doc = FlareFixtures.bounce, hits = LiveHits()
    // A pointer sweeping across the stage: Ball, Shadow, the locked Background and off-canvas.
    let points = [Point(x: 80, y: 100), Point(x: 275, y: 352), Point(x: 500, y: 30), Point(x: 600, y: 450)]
    var move = 0, hit = 0
    let cost = median("hit") {
        if hits.hit(doc, sceneID: "scene-1", frame: 0, at: points[move % points.count], tolerance: 4) != nil { hit += 1 }
        move += 1
    }
    #expect(move == 50 && hit == 26)  // Ball and Shadow on 13 moves each, nothing on the other 24
    #expect(cost <= .milliseconds(10), "QB-L5: a hit took \(cost)")
}

@Test func drawListWithinBudget() {
    let doc = FlareFixtures.bounce, stage = LiveStage()
    var frame = 0, items = 0
    let cost = median("drawList") {
        items += stage.drawList(doc, sceneID: "scene-1", frame: frame % 48, editing: nil).items.count
        frame += 7
    }
    #expect(items == 50 * 3)
    #expect(cost <= .milliseconds(20), "QB-L6: a draw list took \(cost)")
}

/// The ST-2 shape of scene, larger: the scene's layer "host" holds `count` instances of "outer", each of which holds
/// three instances of "leaf", a symbol of two squares; every layer also draws a square of its own.
private func nestedDocument(count: Int) -> Document {
    func box(_ side: Double) -> FlareShape {
        FlareShape(points: [Point(x: 0, y: 0), Point(x: side, y: 0), Point(x: side, y: side), Point(x: 0, y: side)],
                   fill: .solid(FlareColor(r: 0.2, g: 0.4, b: side / 20)))
    }
    let half = [Keyframe(frame: 0, value: 0.5), Keyframe(frame: 24, value: 1)]
    let leaf = Symbol(id: "leaf", name: "Leaf", layers: [
        Layer(id: "leaf-layer", name: "Leaf", shapes: [box(3), box(5)], tracks: ["opacity": half]),
    ])
    let outer = Symbol(id: "outer", name: "Outer", layers: [
        Layer(id: "outer-layer", name: "Outer", shapes: [box(8)], tracks: ["rotation": half],
              instances: (0..<3).map { Instance(symbolID: "leaf", transform: Transform(x: Double($0) * 6, y: 2)) }),
    ])
    let host = Layer(id: "host", name: "Host", shapes: [box(12)], tracks: ["opacity": half],
                     instances: (0..<count).map {
                         Instance(symbolID: "outer", transform: Transform(x: Double($0 % 10) * 50, y: Double($0 / 10) * 40))
                     })
    return Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", layers: [host])], symbols: [outer, leaf])
}

@Test func nestedDrawListWithinBudget() {
    // QB-L11's scale: 125 outer instances, each holding three leaves, is 500 nested instances.
    let doc = nestedDocument(count: 125), stage = LiveStage()
    // Per outer instance: its square, then two squares under each of its three leaf instances.
    let want = 1 + 125 * (1 + 3 * 2)
    #expect(want == 876)
    let first = stage.drawList(doc, sceneID: "scene-1", frame: 12, editing: nil)
    #expect(first.items.count == want)
    #expect(first.items.contains { $0.address.instancePath.count == 1 })
    let cost = median("nestedDrawList") { _ = stage.drawList(doc, sceneID: "scene-1", frame: 12, editing: nil) }
    #expect(cost <= .milliseconds(40), "QB-L11: a nested draw list took \(cost)")
}
