// LiveKeysBudgetTests.swift: KY-9, live-keys' QB-L7 budget (docs/blueprints/flare/features/live-keys.md, Quality
// tests). One drag step through the engine, perform and validate included, on `bounce`: the median of 120 coalesced
// `setValue` scrub steps and the median of 50 coalesced one-frame `moveKeys` steps each stay under budget. The budget
// is fixed per build configuration: CI runs debug, and `swift test -c release --filter LiveKeysBudgetTests` checks
// release. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

#if DEBUG
private let budget = Duration.milliseconds(10)
#else
private let budget = Duration.milliseconds(1)
#endif

private let scene = LayerOwner.scene("scene-1")

struct LiveKeysBudgetTests {
    @Test func scrubStepWithinBudget() throws {
        let props: any PropertyAnimating = LiveProperties()
        let clock = ContinuousClock()
        var engine = CommandEngine(document: FlareFixtures.bounce)
        var costs: [Duration] = []
        costs.reserveCapacity(120)
        for step in 1...120 {
            var failure: (any Error)?
            costs.append(clock.measure {
                do {
                    try props.setValue(Double(step) * 3, of: "rotation", owner: scene, layerIDs: ["ball"], frame: 12,
                                       autoKey: false, coalesceKey: "scrub", in: &engine)
                } catch { failure = error }
            })
            #expect(failure == nil)
        }
        costs.sort()
        print("LiveKeysScrub p50 \(costs[60]) max \(costs[119]) budget \(budget)")
        #expect(costs[60] <= budget)
        try engine.undo()
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }

    @Test func moveKeyStepWithinBudget() throws {
        let keys: any KeyframeEditing = LiveKeyframes()
        let clock = ContinuousClock()
        var engine = CommandEngine(document: FlareFixtures.bounce)
        var costs: [Duration] = []
        costs.reserveCapacity(50)
        for step in 0..<50 {
            let frame = step < 9 ? 12 + step : 21 - (step - 9) % 2  // out to 21, then back and forth between 20 and 21
            var failure: (any Error)?
            costs.append(clock.measure {
                do {
                    try keys.moveKeys([KeyRef(layerID: "ball", property: "x", frame: frame)], by: frame == 21 ? -1 : 1,
                                      owner: scene, coalesceKey: "drag", in: &engine)
                } catch { failure = error }
            })
            #expect(failure == nil)
        }
        costs.sort()
        print("LiveKeysMoveKey p50 \(costs[25]) max \(costs[49]) budget \(budget)")
        #expect(costs[25] <= budget)
        try engine.undo()
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }
}
