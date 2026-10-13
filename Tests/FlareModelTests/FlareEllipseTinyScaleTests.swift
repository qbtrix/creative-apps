// FlareEllipseTinyScaleTests.swift: the Ellipse minimum never shrinks as the
// stage scale does (#496). Down to the smallest positive scales it stays at
// least 1 / scale scene points (or +infinity once that overflows, #502), so a jittery click on a heavily zoomed-out stage adds no layer,
// no draft and no undo step. Zero, negative and infinite scales keep that
// order. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private func ellipseWorkspace() -> FlareWorkspace {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    return workspace
}

private let m = FlareWorkspace.minimumEllipseExtent

@Test func theMinimumNeverShrinksAsTheScaleDoesDownToTheSmallestPositive() {
    // From 1 down past the smallest normal to the smallest subnormal scale.
    var scales = [1.0]
    while let last = scales.last, last > .leastNonzeroMagnitude { scales.append(last / 3) }
    scales.append(.leastNonzeroMagnitude)
    let minimums = scales.map { FlareWorkspace.minimumEllipseExtent(atStageScale: $0) }
    #expect(minimums.allSatisfy { $0 >= m })
    #expect(zip(minimums, minimums.dropFirst()).allSatisfy { $0 <= $1 })
    for (scale, minimum) in zip(scales, minimums) where (m / scale).isFinite {
        #expect(minimum >= m / scale)
    }
}

@Test func outOfRangeScalesKeepTheOrder() {
    let ordered: [Double] = [
        .infinity, .greatestFiniteMagnitude, 4, 1, 0.25, 1e-300,
        .leastNormalMagnitude, .leastNonzeroMagnitude, 0, -0.0, -1, -.infinity,
    ]
    let minimums = ordered.map { FlareWorkspace.minimumEllipseExtent(atStageScale: $0) }
    #expect(minimums.allSatisfy { $0 > 0 })
    #expect(zip(minimums, minimums.dropFirst()).allSatisfy { $0 <= $1 })
    for scale in [0.0, -0.0, -1, -.infinity, .leastNonzeroMagnitude] {
        #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: scale) == .infinity)
    }
}

@Test(arguments: [1e-6, 1e-300, Double.leastNormalMagnitude, .leastNonzeroMagnitude, 0, -1])
func aSubMinimumDragAtATinyScaleRecordsNothing(scale: Double) {
    var workspace = ellipseWorkspace()
    let start = Point(x: 10, y: 10)
    // Far bigger than one scene point, far smaller than one stage point here.
    let end = Point(x: 10 + 1000 * m, y: 10 + 1000 * m)
    #expect(FlareWorkspace.ellipse(from: start, to: end, stageScale: scale) == nil)
    workspace.dragChanged(from: start, to: end, stageScale: scale)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: end, stageScale: scale)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
}

@Test func anInfiniteScaleStillRejectsAnEmptyBox() throws {
    var workspace = ellipseWorkspace()
    let start = Point(x: 10, y: 10)
    workspace.drag(from: start, to: start, stageScale: .infinity)
    #expect(workspace.layers.isEmpty)
    #expect(!workspace.canUndo)
    let end = Point(x: 10 + m / 2, y: 10 + m / 2)
    let shape = try #require(FlareWorkspace.ellipse(from: start, to: end, stageScale: 1e6))
    workspace.drag(from: start, to: end, stageScale: .infinity)
    #expect(workspace.layers.first?.shapes == [shape])
}
