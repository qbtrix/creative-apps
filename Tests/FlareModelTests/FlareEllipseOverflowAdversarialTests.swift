// FlareEllipseOverflowAdversarialTests.swift: adversarial and fuzz checks on
// the Ellipse tool's overflow guard (#484) at extreme coordinates. A box the
// tool can't represent sets no draft, adds no layer, records no undo step and
// reports no error; a box it can represent commits the previewed shape, all
// finite and inside the box, and undo and redo round-trip it. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private let big = Double.greatestFiniteMagnitude

private func allPoints(_ shape: FlareShape) -> [Point] {
    shape.points + (shape.path?.elements ?? []).flatMap { element -> [Point] in
        switch element {
        case .move(let p): [p]
        case .cubic(let c1, let c2, let p): [c1, c2, p]
        default: []
        }
    }
}

/// Checks one extreme drag on a fresh document; returns a failure note or nil.
private func check(_ start: Point, _ end: Point) -> String? {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    let expected = FlareWorkspace.ellipse(from: start, to: end)
    workspace.dragChanged(from: start, to: end)
    if workspace.draft != expected { return "draft differs from ellipse(from:to:)" }
    workspace.drag(from: start, to: end)
    if workspace.layerError != nil { return "layerError \(String(describing: workspace.layerError))" }
    let shapes = workspace.layers.flatMap(\.shapes)
    guard let shape = expected else {
        return shapes.isEmpty && !workspace.canUndo ? nil : "refused box still added a layer or undo step"
    }
    if shapes != [shape] || !workspace.canUndo { return "commit is not the previewed shape" }
    let points = allPoints(shape)
    if !points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) { return "non-finite point" }
    let slack = 1e-9 * max(abs(start.x - end.x), abs(start.y - end.y))
    let inside = points.allSatisfy {
        $0.x >= min(start.x, end.x) - slack && $0.x <= max(start.x, end.x) + slack
            && $0.y >= min(start.y, end.y) - slack && $0.y <= max(start.y, end.y) + slack
    }
    if !inside { return "point outside the box" }
    workspace.undo()
    if !workspace.layers.isEmpty || workspace.layerError != nil { return "undo left a layer" }
    workspace.redo()
    if workspace.layers.flatMap(\.shapes) != [shape] || workspace.layerError != nil { return "redo differs" }
    return nil
}

@Test func theIssueReproDragSetsNoErrorAndCommitsAFiniteEllipse() {
    // #484's repro: before the fix this drag set layerError instead of acting.
    #expect(check(Point(x: 1e308, y: 0), Point(x: 1.5e308, y: 50)) == nil)
    #expect(check(Point(x: -1e308, y: 0), Point(x: -1.5e308, y: 50)) == nil)
    #expect(check(Point(x: 0, y: 1e308), Point(x: 50, y: 1.5e308)) == nil)
}

@Test(arguments: [
    (Point(x: big, y: big), Point(x: big.nextDown, y: big.nextDown)),
    (Point(x: big, y: 0), Point(x: 0, y: big)),
    (Point(x: -big, y: -big), Point(x: 0, y: 0)),
    (Point(x: big, y: -big), Point(x: big - 1e300, y: -big + 1e300)),
    (Point(x: big / 2, y: -big / 2), Point(x: -big / 2, y: big / 2)),
    (Point(x: -big, y: 1), Point(x: -big / 2, y: 1.5)),
])
func edgeOfRangeBoxesAreRefusedCleanlyOrCommitFinitely(start: Point, end: Point) {
    #expect(check(start, end) == nil, "box \(start) → \(end)")
}

@Test func seededExtremeDragsAreRefusedCleanlyOrCommitFinitely() {
    var rng = ExtremeRandom(seed: 484)
    for i in 0..<300 {
        let start = Point(x: rng.extreme(), y: rng.extreme())
        let end = Point(x: rng.extreme(), y: rng.extreme())
        #expect(check(start, end) == nil, "drag \(i): \(start) → \(end)")
    }
}

/// SplitMix64, so the fuzz is the same on every run and platform.
private struct ExtremeRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A signed coordinate between 1e300 and the largest finite Double, or one
    /// a few ULPs below it.
    mutating func extreme() -> Double {
        let unit = Double(next() >> 11) / Double(UInt64(1) << 53)
        let sign: Double = next() % 2 == 0 ? 1 : -1
        switch next() % 4 {
        case 0:
            var v = big
            for _ in 0..<(next() % 4) { v = v.nextDown }
            return sign * v
        default:
            return sign * (1e300 + unit * (big - 1e300))
        }
    }
}
