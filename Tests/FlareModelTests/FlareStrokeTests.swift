// FlareStrokeTests.swift (stroke-style FK-1 written, FK-5 turns on): the nine stroke commands on Flare's workspace as
// a kernel `StrokeTarget`, on `.built`, through a catalog of `StrokeCommands.specs` alone (FK-6 registers them in
// `FlareWorkspace.catalog`). Each command on two selected shapes is one undo step that both take; Trim on an animated
// Trim End keys at the playhead and leaves the other keys; the width clamps to `StrokeRules.widths`; a scrub, a chip
// and a preset are one step each. MJ-FK, the Model walk of the packet's journey, on Linux.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareStrokeTests {
    static let catalog = try? CommandCatalog(app: "flare", StrokeCommands.specs(FlareWorkspace.self),
                                             history: FlareCoreHistory.init)
    static let layers = ["ball", "shadow"]

    /// Bounce on `.built` with Ball's and Shadow's first shapes stroked 2 pt black and both selected; Ball's carries
    /// `trimEnd` as its `trimEnd.0` track when given.
    static func pair(trimEnd: [Keyframe]? = nil) -> FlareWorkspace {
        var doc = FlareFixtures.bounce
        for id in layers {
            guard let i = doc.scenes.first?.layers.firstIndex(where: { $0.id == id }),
                  !doc.scenes[0].layers[i].shapes.isEmpty else { continue }
            doc.scenes[0].layers[i].shapes[0].stroke = VectorStroke(width: 2)
            if id == "ball", let trimEnd { doc.scenes[0].layers[i].tracks["trimEnd.0"] = trimEnd }
        }
        var w = FlareWorkspace(services: .built)
        w.load(doc)
        w.selectLayer("ball")
        w.setSelection(layers.map { StageAddress(owner: .scene("scene-1"), layerID: $0, item: .shape(0)) })
        return w
    }

    /// `id`'s layer in scene 1.
    static func layer(_ w: FlareWorkspace, _ id: String) -> Layer? {
        w.document?.layers(of: .scene("scene-1"))?.first { $0.id == id }
    }

    /// The stored stroke of `id`'s first shape.
    static func stroke(_ w: FlareWorkspace, _ id: String) -> VectorStroke? { layer(w, id)?.shapes.first?.stroke }

    /// How many steps undo can revert, counted on a copy.
    static func steps(_ w: FlareWorkspace) -> Int {
        var copy = w, count = 0
        while copy.canUndo, count < 10_000 { copy.undo(); count += 1 }
        return count
    }

    static func run(_ id: String, _ params: JSONValue, on w: inout FlareWorkspace) throws {
        let catalog = try #require(Self.catalog)
        _ = try catalog.run(id, params: params, on: &w)
    }

    @Test(.disabled("waits on FK-5")) func eachCommandOnTwoShapesIsOneStep() throws {
        var w = Self.pair()
        let runs: [(String, JSONValue)] = [
            ("stroke.color", .object(["r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)])),
            ("stroke.width", .object(["width": .number(6)])),
            ("stroke.join", .object(["join": .string("round")])),
            ("stroke.cap", .object(["cap": .string("round")])),
            ("stroke.dash", .object(["preset": .string("dashed")])),
            ("stroke.trim", .object(["start": .number(0), "end": .number(0.5), "offset": .number(0)])),
            ("stroke.remove", .object([:])),
            ("stroke.add", .object([:])),
        ]
        for (count, (id, params)) in runs.enumerated() {
            try Self.run(id, params, on: &w)
            #expect(Self.steps(w) == count + 1, "\(id) is not one step")
            if id == "stroke.cap" {
                for layer in Self.layers {
                    let s = Self.stroke(w, layer)
                    #expect(s?.width == 6 && s?.cap == .round && s?.join == .round, "\(layer)")
                    #expect(s?.color == FillColor(r: 1, g: 0, b: 0, a: 1), "\(layer)")
                }
            }
            if id == "stroke.remove" { #expect(Self.layers.allSatisfy { Self.stroke(w, $0) == nil }) }
        }
        #expect(Self.layers.allSatisfy { Self.stroke(w, $0) == VectorStroke() }, "add gives both the default stroke")
        w.undo()
        #expect(Self.layers.allSatisfy { Self.stroke(w, $0) == nil }, "one undo reverts add on both")
    }

    @Test(.disabled("waits on FK-5")) func trimOnAnAnimatedTrimEndKeysAtThePlayhead() throws {
        var w = Self.pair(trimEnd: [Keyframe(frame: 0, value: 0), Keyframe(frame: 45, value: 1)])
        w.setCurrentFrame(20)
        let before = Self.stroke(w, "ball")
        try Self.run("stroke.trim", .object(["start": .number(0), "end": .number(0.5), "offset": .number(0)]), on: &w)
        let keys = Self.layer(w, "ball")?.tracks["trimEnd.0"] ?? []
        #expect(keys.map(\.frame) == [0, 20, 45], "the trim landed on the base, not a key at the playhead")
        #expect(keys.first { $0.frame == 20 }?.value == 0.5)
        #expect(keys.first { $0.frame == 0 }?.value == 0 && keys.first { $0.frame == 45 }?.value == 1)
        #expect(Self.stroke(w, "ball").map { StrokeRules.trim(of: $0)?.end } == before.map { StrokeRules.trim(of: $0)?.end },
                "the animated Trim End's base changed")
        #expect(w.selectedStroke.flatMap { StrokeRules.trim(of: $0)?.end } == 0.5, "the read samples the playhead")
        #expect(Self.steps(w) == 1)
        w.undo()
        #expect(Self.layer(w, "ball")?.tracks["trimEnd.0"]?.map(\.frame) == [0, 45])
    }

    @Test(.disabled("waits on FK-5")) func widthClamps() throws {
        var w = Self.pair()
        _ = try? Self.run("stroke.width", .object(["width": .number(5000)]), on: &w)
        #expect(Self.layers.allSatisfy { (Self.stroke(w, $0)?.width ?? 0) <= StrokeRules.widths.upperBound })
        _ = try? Self.run("stroke.width", .object(["width": .number(-3)]), on: &w)
        #expect(Self.layers.allSatisfy { (Self.stroke(w, $0)?.width ?? -1) >= StrokeRules.widths.lowerBound })
    }

    @Test(.disabled("waits on FK-5")) func oneStepPerGesture() throws {
        var w = Self.pair()
        for sample in 0..<120 {
            let params: JSONValue = .object(["width": .number(2 + Double(sample) / 30), "drag": .string("d1")])
            try Self.run("stroke.width", params, on: &w)
        }
        #expect(Self.steps(w) == 1, "a width scrub is one step")
        for sample in 0...60 {
            let params: JSONValue = .object(["start": .number(0), "end": .number(Double(sample) / 60),
                                             "offset": .number(0), "drag": .string("t1")])
            try Self.run("stroke.trim", params, on: &w)
        }
        #expect(Self.steps(w) == 2, "a trim scrub is one step")
        try Self.run("stroke.cap", .object(["cap": .string("square")]), on: &w)
        #expect(Self.steps(w) == 3, "a cap chip is one step")
        try Self.run("stroke.dash", .object(["preset": .string("dotted")]), on: &w)
        #expect(Self.steps(w) == 4, "a dash preset is one step")
        w.undo()
        w.undo()
        w.undo()
        #expect(Self.layers.allSatisfy { Self.stroke(w, $0)?.width == 2 + 119.0 / 30 }, "undo left the scrub's last width")
        w.undo()
        #expect(Self.layers.allSatisfy { Self.stroke(w, $0)?.width == 2 }, "one undo reverts the whole scrub")
    }
}
