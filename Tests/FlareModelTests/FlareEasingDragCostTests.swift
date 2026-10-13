// FlareEasingDragCostTests.swift: the easing editor's quality bar for a handle
// drag. 1000 moves of one handle on a document of 200 layers x 4 tracks x 25
// keys; the p95 cost of one moveEasingHandle must stay under budget. The drag
// runs three times and the quietest p95 counts, because scripts/ci runs every
// suite in parallel and preemption lands in single samples. The budget is fixed
// per build configuration: CI runs debug, and
// `swift test -c release --filter FlareEasingDragCostTests` checks release.
// Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

#if DEBUG
private let budget = Duration.milliseconds(5)
#else
private let budget = Duration.milliseconds(1)
#endif

struct FlareEasingDragCostTests {
    @Test func handleDragP95UnderBudget() {
        let tracks = ["x", "y", "rotation", "opacity"]
        let layers = (0..<200).map { i in
            Layer(id: "layer-\(i)", name: "Layer \(i)", tracks: Dictionary(uniqueKeysWithValues: tracks.map { p in
                (p, (0..<25).map { Keyframe(frame: $0 * 4, value: Double($0)) })
            }))
        }
        var workspace = FlareWorkspace()
        workspace.load(Document(scenes: [Scene(id: "s", name: "S", durationFrames: 100, layers: layers)]))
        workspace.selectLayer("layer-100")
        workspace.selectEasingSegment(EasingSegment(property: "x", startFrame: 40, endFrame: 44))
        #expect(workspace.selectedEasingSegment != nil)

        let clock = ContinuousClock()
        var p95s: [Duration] = []
        for _ in 0..<3 {
            var costs: [Duration] = []
            costs.reserveCapacity(1000)
            for i in 0..<1000 {
                let t = Double(i) / 999
                let point = Point(x: t, y: 1.2 - t)
                costs.append(clock.measure { workspace.moveEasingHandle(.first, to: point) })
            }
            workspace.endEasingHandleDrag()
            costs.sort()
            p95s.append(costs[949])
            print("FlareEasingDragCost p50 \(costs[499]) p95 \(costs[949]) max \(costs[999]) budget \(budget)")
        }
        #expect(workspace.currentEasingHandles?.first == Point(x: 1, y: 1.2 - 1))
        #expect(workspace.layerError == nil)
        #expect((p95s.min() ?? budget * 2) <= budget)
        for _ in 0..<3 { workspace.undo() }
        #expect(workspace.currentEasing == .linear)
        #expect(workspace.canUndo == false)
    }
}
