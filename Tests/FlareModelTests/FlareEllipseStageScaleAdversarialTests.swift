// FlareEllipseStageScaleAdversarialTests.swift: adversarial and fuzz checks on
// the Ellipse tool's stage-point minimum (#483). #483's own repro at fit
// scale 0.5 and its scale-2 case; a fuzz over fit scales where any sub-point
// jitter commits nothing and any drag past one stage point commits exactly one
// Ellipse that matches its draft; a drag that shrinks back under the minimum
// clears its draft; and the minimum never grows as the stage zooms in. Runs on
// Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

/// A fixed-seed generator, so a fuzz failure reproduces.
private struct StageScaleRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Test func issue483ReproAtHalfScaleAddsNothing() {
    var workspace = ellipseWorkspace()
    let scale = 0.5, jitter = 0.6 / scale  // 0.6 stage points = 1.2 scene points
    let start = Point(x: 100, y: 100), end = Point(x: 100 + jitter, y: 100 + jitter)
    workspace.dragChanged(from: start, to: end, stageScale: scale)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end, stageScale: scale)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
    #expect(workspace.layerError == nil)
}

@Test func atScaleTwoASubPointJitterAddsNothingAndOneStagePointDraws() throws {
    let start = Point(x: 40, y: 40)
    // 0.6 stage points at scale 2 is 0.3 scene points: nothing.
    var jittery = ellipseWorkspace()
    jittery.drag(from: start, to: Point(x: 40.3, y: 40.3), stageScale: 2)
    #expect(jittery.layers.isEmpty)
    #expect(!jittery.canUndo)
    // 1.5 stage points at scale 2 is 0.75 scene points: under the scene-point
    // minimum, yet a real drag on screen, so it draws.
    let end = Point(x: 40.75, y: 40.75)
    #expect(FlareWorkspace.ellipse(from: start, to: end) == nil)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end, stageScale: 2))
    var zoomed = ellipseWorkspace()
    zoomed.drag(from: start, to: end, stageScale: 2)
    #expect(zoomed.layers.map(\.name) == ["Ellipse 1"])
    #expect(zoomed.layers.first?.shapes == [shape])
}

@Test func fuzzedScalesAndJitterNeverCommitAndRealDragsCommitOnce() {
    var random = StageScaleRandom(state: 483)
    var failures: [String] = []
    for _ in 0..<300 {
        let decades = [0.001, 0.01, 0.1, 1, 10, 100]
        let scale = Double.random(in: 1..<10, using: &random) * (decades.randomElement(using: &random) ?? 1)
        let start = Point(x: .random(in: -5000...5000, using: &random), y: .random(in: -5000...5000, using: &random))
        // Jitter under 0.9 stage points on each axis, in either direction.
        let jx = Double.random(in: -0.9...0.9, using: &random) / scale
        let jy = Double.random(in: -0.9...0.9, using: &random) / scale
        var jittery = ellipseWorkspace()
        let jitterEnd = Point(x: start.x + jx, y: start.y + jy)
        jittery.dragChanged(from: start, to: jitterEnd, stageScale: scale)
        if jittery.draft != nil { failures.append("jitter draft at scale \(scale)") }
        jittery.drag(from: start, to: jitterEnd, stageScale: scale)
        if !jittery.layers.isEmpty || jittery.canUndo { failures.append("jitter commit at scale \(scale)") }
        // A drag of 1.1 to 400 stage points on each axis.
        let dx = Double.random(in: 1.1...400, using: &random) / scale
        let dy = Double.random(in: 1.1...400, using: &random) / scale
        let end = Point(x: start.x - dx, y: start.y + dy)
        var real = ellipseWorkspace()
        real.dragChanged(from: start, to: end, stageScale: scale)
        let draft = real.draft
        real.drag(from: start, to: end, stageScale: scale)
        if draft == nil || real.layers.flatMap(\.shapes) != [draft].compactMap({ $0 }) {
            failures.append("real drag at scale \(scale) did not commit its draft once")
        }
        if real.draft != nil || real.undoActionName != "Undo Add Ellipse" {
            failures.append("real drag at scale \(scale) left a draft or no undo step")
        }
    }
    #expect(failures.isEmpty, "\(failures.prefix(5))")
}

@Test func aDragThatShrinksBackUnderTheMinimumClearsItsDraft() {
    var workspace = ellipseWorkspace()
    let start = Point(x: 10, y: 10), scale = 0.25
    workspace.dragChanged(from: start, to: Point(x: 90, y: 70), stageScale: scale)
    #expect(workspace.draft != nil)
    // Back to 0.5 stage points (2 scene points) from the start.
    let back = Point(x: 12, y: 12)
    workspace.dragChanged(from: start, to: back, stageScale: scale)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: back, stageScale: scale)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func theMinimumNeverGrowsAsTheStageZoomsIn() {
    // From one millionth to a million times, about 30 steps a decade.
    let scales = (0..<400).reduce(into: [1e-6]) { all, _ in all.append((all.last ?? 1) * 1.08) }
    let minimums = scales.map { FlareWorkspace.minimumEllipseExtent(atStageScale: $0) }
    #expect(minimums.allSatisfy { $0.isFinite && $0 > 0 })
    #expect(zip(minimums, minimums.dropFirst()).allSatisfy { $0 >= $1 })
}
