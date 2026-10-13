// LiveEasingTests.swift: LM-6's acceptance (docs/blueprints/flare.md, 7.5): the preset table golden, curve endpoints
// exact, `SetKeyframeEasing` as one undo step (a coalesced drag too), agreement with `FakeEasing` on `bounce`, and the
// budgets: the curve is FlareCore's `Easing.value(at:)` to the bit, and a coalesced drag step's p95 stays under budget.
import FlareCore
import FlareModel
import Testing

private let live = LiveEasing()
private let owner = LayerOwner.scene("scene-1")
private let custom: [Easing] = [.cubicBezier(x1: 0.1, y1: -0.6, x2: 0.9, y2: 1.7), .cubicBezier(x1: 0, y1: 0, x2: 1, y2: 1)]

/// Each preset at progress 0.25, 0.5 and 0.75 (the CSS timing functions for the cubic ones).
private let golden: [(EasingPreset, String, [Double])] = [
    (.linear, "Linear", [0.25, 0.5, 0.75]),
    (.ease, "Ease", [0.4085105913553958, 0.802403387584857, 0.9604589783489903]),
    (.easeIn, "Ease In", [0.09346465071882484, 0.31535681257253934, 0.621861869173901]),
    (.easeOut, "Ease Out", [0.378138130826099, 0.6846431874274608, 0.9065353492811752]),
    (.easeInOut, "Ease In-Out", [0.12916193104731943, 0.5, 0.8708380689526806]),
    (.hold, "Hold", [0, 0, 0]),
]

@Test func presetTableGolden() {
    #expect(live.presets == golden.map(\.0))
    for (preset, title, values) in golden {
        #expect(preset.title == title)
        let points = live.curve(preset.easing, count: 5)
        #expect(points.map(\.x) == [0, 0.25, 0.5, 0.75, 1])
        for (point, value) in zip(points.dropFirst().dropLast(), values) {
            #expect(abs(point.y - value) < 1e-9, "\(preset) at \(point.x)")
        }
    }
}

@Test func curveEndpointsExact() {
    for easing in golden.map(\.0.easing) + custom {
        for count in [2, 3, 17, 101, LiveEasing.maxCurvePoints] {
            let points = live.curve(easing, count: count)
            #expect(points.count == count)
            #expect(points.first == Point(x: 0, y: 0) && points.last == Point(x: 1, y: 1), "\(easing) \(count)")
        }
    }
}

@Test func curveIsTheEngineValueAndAgreesWithTheFake() {
    for easing in golden.map(\.0.easing) + custom {
        for point in live.curve(easing, count: 64) { #expect(point.y == easing.value(at: point.x)) }
        for count in -1...40 { #expect(live.curve(easing, count: count) == FakeEasing().curve(easing, count: count)) }
    }
    #expect(live.curve(.ease, count: 0).isEmpty && live.curve(.ease, count: Int.min).isEmpty)
    #expect(live.curve(.ease, count: Int.max).count == LiveEasing.maxCurvePoints)
}

private func easing(_ engine: CommandEngine, _ property: String, _ frame: Int) -> Easing? {
    engine.document.layers(of: owner)?.first { $0.id == "ball" }?.tracks[property]?.first { $0.frame == frame }?.easing
}

@Test func setEasingIsOneUndoStepAndAgreesWithTheFake() throws {
    for key in [KeyRef(layerID: "ball", property: "x", frame: 12), KeyRef(layerID: "ball", property: nil, frame: 12)] {
        var engine = CommandEngine(document: FlareFixtures.bounce)
        var fake = CommandEngine(document: FlareFixtures.bounce)
        try live.setEasing(.easeOut, at: key, owner: owner, coalesceKey: nil, in: &engine)
        try FakeEasing().setEasing(.easeOut, at: key, owner: owner, coalesceKey: nil, in: &fake)
        #expect(engine.document == fake.document)
        #expect(easing(engine, "x", 12) == .easeOut && easing(engine, "x", 0) == .linear)
        #expect(easing(engine, "scaleY", 12) == (key.property == nil ? .easeOut : .linear))
        #expect(engine.undoActionName == "Undo Set Keyframe Easing")
        try engine.undo()
        #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
    }
}

@Test func coalescedDragIsOneStepThatUndoesToTheStart() throws {
    var engine = CommandEngine(document: FlareFixtures.bounce)
    for i in 0..<120 {
        let y = Double(i) / 60
        try live.setEasing(.cubicBezier(x1: 0.3, y1: y, x2: 0.7, y2: 1), at: KeyRef(layerID: "ball", property: nil, frame: 24),
                           owner: owner, coalesceKey: "drag-1", in: &engine)
    }
    #expect(easing(engine, "y", 24) == .cubicBezier(x1: 0.3, y1: 119.0 / 60, x2: 0.7, y2: 1))
    try engine.undo()
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}

@Test func refusalsThrowAndChangeNothing() {
    var locked = FlareFixtures.bounce
    locked.scenes[0].layers[2].isLocked = true
    let cases: [(Document, KeyRef, LayerOwner)] = [
        (FlareFixtures.bounce, KeyRef(layerID: "ball", property: "x", frame: 13), owner),
        (FlareFixtures.bounce, KeyRef(layerID: "ball", property: nil, frame: 13), owner),
        (FlareFixtures.bounce, KeyRef(layerID: "missing", property: "x", frame: 12), owner),
        (FlareFixtures.bounce, KeyRef(layerID: "ball", property: "x", frame: 12), .symbol("symbol-1")),
        (locked, KeyRef(layerID: "ball", property: nil, frame: 12), owner),
        (locked, KeyRef(layerID: "ball", property: "x", frame: 12), owner),
    ]
    for (document, key, owner) in cases {
        for coalesceKey in [nil, "drag"] as [String?] {
            var engine = CommandEngine(document: document)
            #expect(throws: (any Error).self) {
                try live.setEasing(.ease, at: key, owner: owner, coalesceKey: coalesceKey, in: &engine)
            }
            #expect(engine.document == document && !engine.canUndo)
        }
    }
}

#if DEBUG
private let budget = Duration.milliseconds(5)
#else
private let budget = Duration.milliseconds(1)
#endif

/// A handle drag (QB-L2, handle): 1000 coalesced summary-key steps on `bounce`. The quietest of three p95s counts,
/// because `scripts/ci` runs suites in parallel and preemption lands in single samples.
@Test func coalescedDragStepP95UnderBudget() throws {
    let clock = ContinuousClock()
    var engine = CommandEngine(document: FlareFixtures.bounce)
    var p95s: [Duration] = []
    for run in 0..<3 {
        var costs: [Duration] = []
        for i in 0..<1000 {
            let easing = Easing.cubicBezier(x1: Double(i) / 999, y1: 1.2, x2: 0.6, y2: 1)
            var failure: (any Error)?
            costs.append(clock.measure {
                do { try live.setEasing(easing, at: KeyRef(layerID: "ball", property: nil, frame: 36), owner: owner,
                                        coalesceKey: "drag-\(run)", in: &engine) } catch { failure = error }
            })
            #expect(failure == nil)
        }
        costs.sort()
        p95s.append(costs[949])
        print("LiveEasingDrag p50 \(costs[499]) p95 \(costs[949]) max \(costs[999]) budget \(budget)")
    }
    #expect((p95s.min() ?? budget * 2) <= budget)
    for _ in 0..<3 { try engine.undo() }
    #expect(engine.document == FlareFixtures.bounce && !engine.canUndo)
}
