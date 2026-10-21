// DesignStrokeTests.swift (stroke-style DK-1 written, DK-6 turns on): Design's stroke as the kernel's. A node's
// `vectorStroke` keeps its colour and width with the default join and cap; the workspace as a `StrokeTarget` says
// why nothing can be stroked and why trim never runs in Design; the inspector's bridge turns the editor's intents
// into style changes until DK-6 runs them through the catalog. The stroke commands on Design (one step for the
// whole selection, a locked layer skipped, the width clamped, trim refused) are disabled until DK-6 registers them.
// MJ-DK, the Model walk of the packet's journey, on Linux.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignStrokeTests {
    /// `cards` with A, B and C selected, A primary.
    static var threeSelected: DesignWorkspace {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        w.toggleSelection("node-3")
        w.toggleSelection("node-4")
        return w
    }

    static func stroke(_ w: DesignWorkspace, _ id: String) -> VectorStroke? { w.selectedPage?.nodes.node(id)?.vectorStroke }

    @Test func vectorStrokeMapsColourAndWidth() {
        let red = DesignNode(id: "r", name: "R", kind: .rectangle, frame: DesignRect(x: 0, y: 0, width: 10, height: 10),
                             stroke: DesignStroke(color: DesignColor(255, 0, 0), width: 4))
        #expect(red.vectorStroke == VectorStroke(color: FillColor(r: 1, g: 0, b: 0), width: 4))
        #expect(red.vectorStroke?.join == VectorStroke().join && red.vectorStroke?.cap == VectorStroke().cap)
        #expect(StrokeRules.preset(of: red.vectorStroke ?? VectorStroke()) == .solid)
        let plain = DesignNode(id: "p", name: "P", kind: .rectangle, frame: DesignRect(x: 0, y: 0, width: 10, height: 10))
        #expect(plain.vectorStroke == nil)
    }

    @Test func targetSaysWhyNothingCanBeStroked() {
        #expect(DesignWorkspace().strokeHelp == "Open a design first.")
        #expect(DesignFixtures.cards.strokeHelp == "Select a layer first.")
        var one = DesignFixtures.cards
        one.selectItem("node-2")
        #expect(one.strokeHelp == nil)
        #expect(one.trimHelp == "Trim paths are for animation, in Flare and Halo.")
        #expect(one.selectedStroke == nil)
    }

    @Test func selectedStrokeIsThePrimaryLayers() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        try w.setStyle(.stroke(DesignStroke(color: DesignColor(0, 0, 255), width: 3)))
        #expect(w.selectedStroke == VectorStroke(color: FillColor(r: 0, g: 0, b: 1), width: 3))
    }

    @Test func editorIntentsBecomeStyleChanges() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        #expect(w.strokeChange(.add)?.change == .stroke(.default))
        #expect(w.strokeChange(.width(4, drag: nil)) == nil, "no stroke to widen yet")
        try w.setStyle(.stroke(DesignStroke(color: DesignColor(255, 0, 0), width: 2)))
        #expect(w.strokeChange(.remove)?.change == .stroke(nil))
        let scrub = try #require(w.strokeChange(.width(5000, drag: "d1")))
        #expect(scrub.change == .stroke(DesignStroke(color: DesignColor(255, 0, 0), width: 1000)) && scrub.scrub)
        let blue = w.strokeChange(.color(FillColor(r: 0, g: 0, b: 1), drag: nil))
        #expect(blue?.change == .stroke(DesignStroke(color: DesignColor(0, 0, 255), width: 2)) && blue?.scrub == false)
        #expect(w.strokeChange(.cap(.round)) == nil, "caps wait on DK-5's stroke type")
    }

    @Test(.disabled("waits on DK-6")) func eachCommandIsOneStepForTheSelection() throws {
        var w = Self.threeSelected
        let runs: [(String, JSONValue)] = [
            ("stroke.add", .object([:])), ("stroke.width", .object(["width": .number(2)])),
            ("stroke.cap", .object(["cap": .string("round")])), ("stroke.join", .object(["join": .string("round")])),
        ]
        for (count, (id, params)) in runs.enumerated() {
            _ = try DesignWorkspace.catalog.run(id, params: params, on: &w)
            #expect(w.history.kernel.steps.count == count + 1, "\(id) is not one step")
        }
        for id in ["node-2", "node-3", "node-4"] {
            #expect(Self.stroke(w, id)?.width == 2 && Self.stroke(w, id)?.cap == .round, "\(id)")
        }
    }

    @Test(.disabled("waits on DK-6")) func oneStepPerGesture() throws {
        var w = Self.threeSelected
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        for sample in 0..<120 {
            let params: JSONValue = .object(["width": .number(1 + Double(sample) / 30), "drag": .string("d1")])
            _ = try DesignWorkspace.catalog.run("stroke.width", params: params, on: &w)
        }
        #expect(w.history.kernel.steps.count == 2, "a width scrub is one step")
        w.undo()
        #expect(Self.stroke(w, "node-3")?.width == 1)
    }

    @Test(.disabled("waits on DK-6")) func aLockedLayerIsSkipped() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        w.toggleSelection("node-9")
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        #expect(Self.stroke(w, "node-2") != nil)
        #expect(Self.stroke(w, "node-9") == nil, "the locked layer took a stroke")
    }

    @Test(.disabled("waits on DK-6")) func widthClamps() throws {
        var w = Self.threeSelected
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        _ = try? DesignWorkspace.catalog.run("stroke.width", params: .object(["width": .number(5000)]), on: &w)
        #expect((Self.stroke(w, "node-2")?.width ?? 0) <= StrokeRules.widths.upperBound)
    }

    @Test(.disabled("waits on DK-6")) func trimIsUnavailableWithTheTrimHelp() throws {
        var w = Self.threeSelected
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        #expect(DesignWorkspace.catalog.availability("stroke.trim", on: w)
            == .unavailable("Trim paths are for animation, in Flare and Halo."))
    }
}
