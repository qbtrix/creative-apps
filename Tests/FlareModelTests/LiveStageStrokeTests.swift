// LiveStageStrokeTests.swift: the live stage strokes what the SVG export strokes, the outline trimmed and dashed
// (`RenderItem.strokePath`), so a trimmed or dashed stroke draws the same on the stage, in PNG frames and in SVG.
// Runs on Linux and macOS.
import FlareCore
import FlareModel
import Testing

private let square = FlarePath(polyline: [Point(x: 10, y: 10), Point(x: 90, y: 10), Point(x: 90, y: 90),
                                          Point(x: 10, y: 90)], closed: true)

private func item(_ stroke: Stroke) throws -> StageItem {
    let shape = FlareShape(points: [], fill: .solid(FlareColor(r: 0, g: 0, b: 0, a: 0)), path: square, stroke: stroke)
    let scene = FlareScene(id: "s", name: "S", width: 100, height: 100, layers: [Layer(id: "l", name: "L", shapes: [shape])])
    return try #require(LiveStage().drawList(Document(scenes: [scene]), sceneID: "s", frame: 0, editing: nil).items.first)
}

@Test func aTrimmedStrokePaintsTheTrimmedOutline() throws {
    var stroke = Stroke(width: 10)
    stroke.trim = StrokeTrim(start: 0, end: 0.5)
    let drawn = try item(stroke)
    #expect(drawn.path == square)
    #expect(drawn.strokePath == (try stroke.paintedPath(square, tolerance: SVGExporter.strokeTolerance)))
    #expect(drawn.strokePath?.bounds == Rect(minX: 10, minY: 10, maxX: 90, maxY: 90 ))
    #expect(drawn.strokePath != square)
}

@Test func aDashedStrokePaintsTheDashes() throws {
    var stroke = Stroke(width: 2)
    stroke.dash = [10, 10]
    let drawn = try item(stroke)
    #expect(drawn.strokePath == (try stroke.paintedPath(square, tolerance: SVGExporter.strokeTolerance)))
    #expect(drawn.strokePath != nil)
}

@Test func aPlainStrokePaintsTheOutline() throws {
    #expect(try item(Stroke(width: 2)).strokePath == nil)
}
