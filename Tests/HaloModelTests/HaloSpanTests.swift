// HaloSpanTests.swift (timeline-keys TK-2 checks, TK-6 turns them on):
// Halo's `layer.slide` and `layer.trim` through its catalog. A slide moves a
// layer's in, out and every key by one clamped delta (`SpanRules.slide`); a
// trim moves one edge and leaves the keys; each is one undo step, and a drag
// under one token is one step. A null's children keep their own spans.
// `specsDeclared` checks TK-2's specs now. MJ-TK-halo; Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

/// "Stagger" (72 frames at 24 fps): Ball (12..<36; x keyed at 12 and 24,
/// opacity at 12 and 18) following Rig, a null (0..<48; x at 0 and 47).
private func stagger() -> (project: HaloProject, ball: String, rig: String) {
    var ball = HaloFixtures.layer(1, 2, "Ball", .solid, 12..<36)
    ball.tracks["x"] = HaloFixtures.keys([(12, 160), (24, 960)])
    ball.tracks["opacity"] = HaloFixtures.keys([(12, 0), (18, 1)])
    var rig = HaloFixtures.layer(1, 1, "Rig", .null, 0..<48)
    rig.tracks["x"] = HaloFixtures.keys([(0, 960), (47, 1160)])
    ball.parentID = rig.id
    var project = HaloProject(services: .fake)
    project.restore(HaloFixtures.document([HaloFixtures.comp(1, "Stagger", fps: 24, frames: 72, layers: [ball, rig])]))
    return (project, ball.id, rig.id)
}

private func layer(_ project: HaloProject, _ id: String) -> HaloLayer? {
    project.selectedComposition?.layers.first { $0.id == id }
}

private func frames(_ project: HaloProject, _ id: String) -> [String: [Int]] {
    layer(project, id)?.tracks.mapValues { $0.map(\.frame) } ?? [:]
}

private func slide(_ id: String, by: Int, drag: String? = nil) -> JSONValue {
    var params: [String: JSONValue] = ["layer": .string(id), "by": .number(Double(by))]
    if let drag { params["drag"] = .string(drag) }
    return .object(params)
}

private func trim(_ id: String, _ edge: String, to frame: Int) -> JSONValue {
    .object(["layer": .string(id), "edge": .string(edge), "frame": .number(Double(frame))])
}

@Suite struct HaloSpanTests {
    let catalog = HaloProject.catalog

    @Test func specsDeclared() {
        let specs = HaloProject.spanCommands
        #expect(specs.map(\.id) == ["layer.slide", "layer.trim"])
        #expect(specs.map(\.title) == ["Slide Layer", "Trim Layer"])
        #expect(specs.allSatisfy { $0.kind == .edit })
        #expect(specs.allSatisfy { $0.params.validate($0.example).isEmpty })
        #expect(specs.first?.params.validate(.object(["layer": .string("x")])).isEmpty == false)
        let empty = commandProject("empty", .fake)
        #expect(specs.allSatisfy { $0.availability(empty).why != nil })
    }

    @Test(.disabled("waits on TK-6")) func slideMovesSpanAndKeys() throws {
        var (project, ball, _) = stagger()
        #expect(try catalog.run("layer.slide", params: slide(ball, by: 6), on: &project).undoStep == "Slide Layer")
        #expect(layer(project, ball)?.inFrame == 18 && layer(project, ball)?.outFrame == 42)
        #expect(frames(project, ball) == ["x": [18, 30], "opacity": [18, 24]])
        #expect(project.history.undo.count == 1)
        project.undo()
        #expect(layer(project, ball)?.inFrame == 12 && frames(project, ball) == ["x": [12, 24], "opacity": [12, 18]])
    }

    @Test(.disabled("waits on TK-6")) func dragIsOneStep() throws {
        var (project, ball, _) = stagger()
        for _ in 0..<30 { _ = try catalog.run("layer.slide", params: slide(ball, by: 1, drag: "bar-1"), on: &project) }
        #expect(project.history.undo.count == 1)
        #expect(layer(project, ball)?.inFrame == 42 && layer(project, ball)?.outFrame == 66)
        #expect(frames(project, ball) == ["x": [42, 54], "opacity": [42, 48]])
    }

    @Test(.disabled("waits on TK-6")) func slideClampsAtTheEnd() throws {
        var (project, ball, _) = stagger()
        _ = try catalog.run("layer.slide", params: slide(ball, by: 100), on: &project)
        #expect(layer(project, ball)?.inFrame == 48 && layer(project, ball)?.outFrame == 72)
        #expect(frames(project, ball) == ["x": [48, 60], "opacity": [48, 54]])
    }

    @Test(.disabled("waits on TK-6")) func trimMovesOnlyTheEdge() throws {
        var (project, ball, _) = stagger()
        #expect(try catalog.run("layer.trim", params: trim(ball, "end", to: 23), on: &project).undoStep == "Trim Layer")
        #expect(layer(project, ball)?.inFrame == 12 && layer(project, ball)?.outFrame == 24)
        _ = try catalog.run("layer.trim", params: trim(ball, "start", to: 15), on: &project)
        #expect(layer(project, ball)?.inFrame == 15 && layer(project, ball)?.outFrame == 24)
        #expect(frames(project, ball) == ["x": [12, 24], "opacity": [12, 18]])
        #expect(project.history.undo.count == 2)
    }

    @Test(.disabled("waits on TK-6")) func nullChildrenKeepTheirSpans() throws {
        var (project, ball, rig) = stagger()
        _ = try catalog.run("layer.slide", params: slide(rig, by: 6), on: &project)
        #expect(layer(project, rig)?.inFrame == 6 && frames(project, rig) == ["x": [6, 53]])
        #expect(layer(project, ball)?.inFrame == 12 && layer(project, ball)?.outFrame == 36)
        #expect(frames(project, ball) == ["x": [12, 24], "opacity": [12, 18]])
        #expect(layer(project, ball)?.parentID == rig)
    }

    @Test(.disabled("waits on TK-6")) func unknownLayerRefuses() {
        var (project, _, _) = stagger()
        let before = project.selectedComposition
        #expect(throws: CatalogError.self) { try catalog.run("layer.slide", params: slide("nope", by: 6), on: &project) }
        #expect(project.selectedComposition == before && project.history.undo.isEmpty)
    }
}
