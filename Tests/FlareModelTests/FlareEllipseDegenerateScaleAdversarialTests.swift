// FlareEllipseDegenerateScaleAdversarialTests.swift: tries to break #502's
// rule that a degenerate stage scale refuses every Ellipse box. Negative
// subnormal and huge scales, NaNs with a sign or payload, a degenerate scale
// arriving mid-gesture after a live draft, and the redo history and selection
// a refused drag must leave alone. Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private let oddDegenerateScales: [Double] = [
    -.leastNonzeroMagnitude, -.leastNormalMagnitude, -.greatestFiniteMagnitude,
    -Double.nan, .signalingNaN, Double(nan: 0x1234, signaling: false), .leastNonzeroMagnitude * 2,
]

@Test(arguments: oddDegenerateScales)
func anOddDegenerateScaleHasAMinimumNoBoxMeets(scale: Double) {
    #expect(FlareWorkspace.minimumEllipseExtent(atStageScale: scale) == .infinity)
    let start = Point(x: -.greatestFiniteMagnitude / 2, y: -.greatestFiniteMagnitude / 2)
    let end = Point(x: .greatestFiniteMagnitude / 2, y: .greatestFiniteMagnitude / 2)
    #expect(FlareWorkspace.ellipse(from: start, to: end, stageScale: scale) == nil)
}

@Test(arguments: [0, -1, -Double.infinity, .nan, .leastNonzeroMagnitude])
func aScaleTurningDegenerateMidGestureDropsTheDraftAndKeepsHistory(scale: Double) throws {
    var workspace = FlareWorkspace()
    workspace.newDocument()
    workspace.selectTool(.ellipse)
    let start = Point(x: 0, y: 0), end = Point(x: 50, y: 50)
    // One committed, undone ellipse leaves a redo step a new commit would drop.
    workspace.drag(from: start, to: end, stageScale: 1)
    workspace.undo()
    #expect(workspace.canRedo)
    let selected = workspace.selectedLayerID
    workspace.dragChanged(from: start, to: end, stageScale: 1)
    #expect(workspace.draft != nil)
    let far = Point(x: .greatestFiniteMagnitude, y: .greatestFiniteMagnitude)
    workspace.dragChanged(from: start, to: far, stageScale: scale)
    #expect(workspace.draft == nil)
    workspace.drag(from: start, to: far, stageScale: scale)
    #expect(workspace.draft == nil)
    #expect(workspace.layers.isEmpty)
    #expect(workspace.selectedLayerID == selected)
    #expect(workspace.canRedo)
    // Back at a sane scale the same tool commits, as "Ellipse 1".
    workspace.drag(from: start, to: end, stageScale: 1)
    let layer = try #require(workspace.layers.first)
    #expect(layer.name == "Ellipse 1")
}
