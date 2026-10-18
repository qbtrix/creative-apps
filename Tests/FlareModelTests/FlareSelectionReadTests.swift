// FlareSelectionReadTests.swift: stage-edit SE-1, the selection readout on `.fake()` and `.built`.
import FlareCore
@testable import FlareModel
import Testing

private func services(_ name: String) -> FlareServices { name == "built" ? .built : .fake() }

private let ballAt = Point(x: 80, y: 100), shadowAt = Point(x: 275, y: 352)

private func bounce(_ name: String, clicking points: [Point]) -> FlareWorkspace {
    var workspace = FlareWorkspace(services: services(name))
    workspace.load(FlareFixtures.bounce)
    workspace.selectTool(.select)
    for (i, p) in points.enumerated() { workspace.drag(from: p, to: p, modifiers: i == 0 ? [] : .shift) }
    return workspace
}

private func near(_ a: Double?, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { a.map { abs($0 - b) <= tolerance } ?? false }

@Test(arguments: ["fake", "built"])
func ballAloneReadsOneSelectedAndItsBox(_ name: String) throws {
    let workspace = bounce(name, clicking: [ballAt])
    let readout = workspace.selectionReadout
    #expect(readout.count == 1 && workspace.selectedLayerIDs == ["ball"])
    let box = try #require(readout.box)
    #expect(box == workspace.selectionBounds && box.minX < ballAt.x && ballAt.x < box.maxX && box.minY < ballAt.y && ballAt.y < box.maxY)
    #expect(readout.scaleX == 1 && readout.scaleY == 1 && readout.rotation == 0)
    #expect(readout.text == "1 selected, scale 1.00 × 1.00, rotation 0°")
}

@Test(arguments: ["fake", "built"])
func ballAndShadowReadTwoSelectedAndTheirUnion(_ name: String) throws {
    let ball = try #require(bounce(name, clicking: [ballAt]).selectionReadout.box)
    let shadow = try #require(bounce(name, clicking: [shadowAt]).selectionReadout.box)
    let readout = bounce(name, clicking: [ballAt, shadowAt]).selectionReadout
    #expect(readout.count == 2)
    let box = try #require(readout.box)
    #expect(near(box.minX, min(ball.minX, shadow.minX)) && near(box.minY, min(ball.minY, shadow.minY)))
    #expect(near(box.maxX, max(ball.maxX, shadow.maxX)) && near(box.maxY, max(ball.maxY, shadow.maxY)))
}

@Test(arguments: ["fake", "built"])
func aMarqueeOverBallAndShadowReadsTwoAndAnEmptyClickZero(_ name: String) {
    var workspace = bounce(name, clicking: [ballAt])
    workspace.drag(from: Point(x: 450, y: 60), to: Point(x: 450, y: 60))
    let none = workspace.selectionReadout
    #expect(none.count == 0 && none.box == nil && none.handles.isEmpty && none.scaleX == nil && none.rotation == nil)
    workspace.drag(from: Point(x: 40, y: 60), to: Point(x: 330, y: 370))
    #expect(workspace.selectionReadout.count == 2 && Set(workspace.selectedLayerIDs) == ["ball", "shadow"])
}

@Test(arguments: ["fake", "built"])
func aScalePreviewReadsOnePointFiveBeforeMouseUp(_ name: String) throws {
    var workspace = bounce(name, clicking: [ballAt])
    let box = try #require(workspace.selectionBounds)
    let grip = Point(x: box.maxX + 2, y: box.maxY - 2)
    workspace.dragChanged(from: grip, to: Point(x: grip.x + box.width / 2, y: grip.y + box.height / 2))
    let readout = workspace.selectionReadout
    #expect(!workspace.canUndo, "the preview committed")
    #expect(near(readout.scaleX, 1.5) && near(readout.scaleY, 1.5), "\(readout.text)")
    let live = try #require(readout.box)
    #expect(near(live.minX, box.minX) && near(live.width, box.width * 1.5) && near(live.height, box.height * 1.5))
    #expect(readout.text == "1 selected, scale 1.50 × 1.50, rotation 0°")
    workspace.endDrag()
    #expect(near(workspace.selectionReadout.scaleX, 1.5) && workspace.undoActionName == "Undo Scale")
}

@Test(arguments: ["fake", "built"])
func aQuarterTurnCommitReadsRotationNinety(_ name: String) throws {
    var workspace = bounce(name, clicking: [ballAt])
    let box = try #require(workspace.selectionBounds)
    let zone = try #require(workspace.selectionReadout.handles.first { $0.kind == .rotate }).point
    let centre = Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2), arm = centre.y - zone.y
    workspace.dragChanged(from: zone, to: Point(x: centre.x + arm, y: centre.y))
    #expect(near(workspace.selectionReadout.rotation, 90), "the preview doesn't read the turn")
    #expect(workspace.selectionReadout.box == box, "a turn moved the box it turns about")
    workspace.endDrag()
    let readout = workspace.selectionReadout
    #expect(workspace.undoActionName == "Undo Rotate" && near(readout.rotation, 90) && readout.count == 1)
    #expect(readout.text.hasSuffix(", rotation 90°"))
}

@Test(arguments: ["fake", "built"])
func layersThatDifferReadMixed(_ name: String) throws {
    var workspace = bounce(name, clicking: [ballAt])
    let box = try #require(workspace.selectionBounds)
    let grip = Point(x: box.maxX + 2, y: box.maxY - 2)
    workspace.drag(from: grip, to: Point(x: grip.x + box.width / 2, y: grip.y + box.height / 2))
    workspace.drag(from: shadowAt, to: shadowAt, modifiers: .shift)
    let readout = workspace.selectionReadout
    #expect(readout.count == 2 && readout.scaleX == nil && readout.scaleY == nil && readout.rotation == 0)
    #expect(readout.text == "2 selected, scale mixed × mixed, rotation 0°")
}

@Test(arguments: ["fake", "built"])
func theHandlesAreEightAtTheCornersAndEdgeMiddlesWithTheRotateZone(_ name: String) throws {
    let readout = bounce(name, clicking: [ballAt]).selectionReadout(stageScale: 2)
    let box = try #require(readout.box)
    let (midX, midY) = ((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2)
    let want: [(StageHandle.Kind, Double, Double)] = [
        (.corner(0), box.minX, box.minY), (.corner(1), box.maxX, box.minY), (.corner(2), box.maxX, box.maxY),
        (.corner(3), box.minX, box.maxY), (.edge(0), midX, box.minY), (.edge(1), box.maxX, midY),
        (.edge(2), midX, box.maxY), (.edge(3), box.minX, midY), (.rotate, midX, box.minY - 12),
    ]
    for (handle, (kind, x, y)) in zip(readout.handles, want) {
        #expect(handle.kind == kind && near(handle.point.x, x) && near(handle.point.y, y), "\(kind)")
    }
    let rects = readout.handleRects(stageScale: 2)
    #expect(readout.handles.count == 9 && rects.count == 9 && rects.values.allSatisfy { near($0.width, 6) && near($0.height, 6) })
}

@Test func fixedRoundsToItsPlaces() {
    let cases: [(Double, Int, String)] = [(1.5, 2, "1.50"), (0.125, 2, "0.13"), (1.05, 2, "1.05"), (-0.25, 2, "-0.25"),
                                          (-0.001, 2, "0.00"), (89.6, 0, "90"), (-90, 0, "-90"), (.nan, 2, "mixed")]
    for (value, places, want) in cases { #expect(SelectionReadout.fixed(value, places: places) == want, "\(value)") }
}
