// FlareGradientTests.swift: gradient-fill FG-1 (MJ-FG, the Model walk). The readout half runs now: the selection's
// fill and its bounds, the paint readout's gradient, and the no-shape help. The command half is written against the
// FG-5 bodies and stays disabled until FG-5 turns it on: `fill.angle` 90 rewrites the points to the bounds' top and
// bottom middle, a stop colour keeps them, two shapes take one undo step and a 120-move drag is one step.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private let threeStops = [GradientStop(offset: 0, color: .black), GradientStop(offset: 0.5, color: .white),
                          GradientStop(offset: 1, color: .black)]

/// Bounce with every Ball shape's fill set to `fill`, Ball selected, on `.built`. `twoShapes` adds the Shadow's ellipse
/// to Ball after its circle, so Ball holds two shapes with different bounds.
private func ball(_ fill: FlareCore.Fill? = nil, twoShapes: Bool = false) -> FlareWorkspace {
    var doc = FlareFixtures.bounce
    if let i = doc.scenes.first?.layers.firstIndex(where: { $0.id == "ball" }) {
        if twoShapes, let shadow = doc.scenes[0].layers.first(where: { $0.id == "shadow" })?.shapes.first {
            doc.scenes[0].layers[i].shapes.append(shadow)
        }
        if let fill { for s in doc.scenes[0].layers[i].shapes.indices { doc.scenes[0].layers[i].shapes[s].fill = fill } }
    }
    var w = FlareWorkspace(services: .built)
    w.load(doc)
    w.selectLayer("ball")
    return w
}

private func ballShapes(_ w: FlareWorkspace) -> [FlareShape] {
    w.document?.layers(of: .scene("scene-1"))?.first { $0.id == "ball" }?.shapes ?? []
}

/// A left-to-right linear fill across `box`'s middle.
private func across(_ box: FlareCore.Rect) -> FlareCore.Fill {
    let y = (box.minY + box.maxY) / 2
    return .linear(stops: threeStops, start: Point(x: box.minX, y: y), end: Point(x: box.maxX, y: y))
}

@Suite struct FlareGradientTests {
    @Test func fillSelectionIsTheFirstShapesFillInItsBounds() throws {
        let w = ball()
        let shape = try #require(ballShapes(w).first)
        let selection = try #require(w.fillSelection)
        #expect(selection.fill == shape.fill)
        #expect(selection.box == shape.bounds)
        #expect(w.fillHelp == FlareWorkspace.fillNotBuilt, "FG-5 registers the fill commands and retires this reason")
    }

    @Test func fillSelectionIsTheFirstOfSeveralShapesInItsBounds() throws {
        let box = try #require(ballShapes(ball()).first?.bounds)
        let w = ball(across(box), twoShapes: true)
        let shapes = ballShapes(w)
        try #require(shapes.count == 2)
        let first = try #require(shapes.first?.bounds), second = try #require(shapes.last?.bounds)
        try #require(first != second)
        let selection = try #require(w.fillSelection)
        #expect(selection.box == first)
        #expect(selection.box != second)
        #expect(selection.fill == across(box))
    }

    @Test func nothingSelectedHasNoFillAndSaysWhy() {
        var w = FlareWorkspace(services: .built)
        w.load(FlareFixtures.bounce)
        #expect(w.fillSelection == nil)
        #expect(w.fillHelp == "Select a shape first.")
    }

    @Test func paintCarriesTheGradientAndNotASolid() throws {
        #expect(ball().paint?.gradient == nil)
        let box = try #require(ballShapes(ball()).first?.bounds)
        let w = ball(across(box))
        #expect(w.paint?.gradient == w.fillSelection)
        #expect(w.paint?.gradient?.fill == across(box))
    }

    @Test func runFillRefusesWithAReasonUntilTheCommandsAreBuilt() {
        var w = ball()
        let before = w.document
        w.runFill(.type(.linear))
        #expect(w.document == before && !w.canUndo)
        #expect(w.paintError != nil)
    }
}

@Suite(.disabled("FG-5 builds the fill command bodies"))
struct FlareGradientCommandTests {
    @Test func angleRewritesPoints() throws {
        let box = try #require(ballShapes(ball()).first?.bounds)
        var w = ball(across(box))
        w.runFill(.angle(90, drag: nil))
        guard case .linear(_, let start, let end)? = ballShapes(w).first?.fill else { return #expect(Bool(false)) }
        #expect(abs(start.x - (box.minX + box.maxX) / 2) < 1e-9 && abs(end.x - start.x) < 1e-9)
        #expect(abs(start.y - box.minY) < 1e-9 && abs(end.y - box.maxY) < 1e-9)
    }

    @Test func stopColorKeepsThePoints() throws {
        let box = try #require(ballShapes(ball()).first?.bounds)
        var w = ball(across(box))
        w.runFill(.color(index: 1, FillColor(r: 1, g: 0, b: 0), drag: nil))
        guard case .linear(let stops, let start, let end)? = ballShapes(w).first?.fill,
              case .linear(_, let oldStart, let oldEnd) = across(box) else { return #expect(Bool(false)) }
        #expect(stops[1].color == FillColor(r: 1, g: 0, b: 0))
        #expect(start == oldStart && end == oldEnd)
    }

    @Test func oneStepForSeveral() throws {
        let box = try #require(ballShapes(ball()).first?.bounds)
        var w = ball(across(box), twoShapes: true)
        let before = w.document
        try #require(ballShapes(w).count > 1)
        w.runFill(.type(.radial))
        #expect(ballShapes(w).allSatisfy { if case .radial = $0.fill { true } else { false } })
        w.undo()
        #expect(w.document == before && !w.canUndo)
    }

    @Test func dragIsOneStep() throws {
        let box = try #require(ballShapes(ball()).first?.bounds)
        var w = ball(across(box))
        let before = w.document
        for i in 0..<120 { w.runFill(.move(index: 1, offset: Double(i) / 120, drag: "stop-drag")) }
        #expect(w.document != before)
        w.undo()
        #expect(w.document == before && !w.canUndo)
    }
}
