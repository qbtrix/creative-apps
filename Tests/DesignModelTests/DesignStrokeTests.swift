// DesignStrokeTests.swift (stroke-style DK-1 written, DK-6 turns on): Design's stroke as the kernel's. A node's
// `vectorStroke` is its stroke; the workspace as a `StrokeTarget` says why nothing can be stroked and why trim never
// runs in Design; the inspector's bridge turns each editor intent (join, cap and dash included) into a style change
// through the kernel's command. The stroke commands on Design are one step for the whole selection, skip a locked
// layer, clamp the width and refuse trim. MJ-DK, the Model walk of the packet's journey, on Linux.
// DesignStrokeMigrationTests (DK-5): a file saved before the feature, its strokes `{color, width}` in 0...255 bytes,
// opens with each stroke's colour and width and the default join and cap; a file saved now round-trips the join, the
// cap and the dash.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
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
        let green = try #require(w.strokeChange(.color(FillColor(r: 0, g: 1, b: 0), drag: "c1")))
        #expect(green.change == .stroke(DesignStroke(color: DesignColor(0, 255, 0), width: 2)))
        #expect(green.scrub, "a colour scrub's sample is previewed, not one undo step each")
        let round = try #require(w.strokeChange(.cap(.round)), "a cap is the kernel's command now")
        #expect(round.change == .stroke(VectorStroke(color: FillColor(r: 1, g: 0, b: 0), width: 2, cap: .round)))
        let dashed = try #require(w.strokeChange(.dash(.dashed, pattern: nil)))
        #expect(dashed.change == .stroke(VectorStroke(color: FillColor(r: 1, g: 0, b: 0), width: 2, dash: [8, 4])))
        #expect(w.strokeChange(.trim(start: 0, end: 0.5, offset: 0, drag: nil)) == nil, "no trim in Design")
    }

    /// No dead controls (#3865): on a stroked layer every Join, Cap and Dash chip changes the stroke, so none needs a
    /// reason.
    @Test func everyEnabledEditorRowActs() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        #expect(w.strokeStyleHelp == nil, "no stroke: the editor shows Add Stroke alone")
        try w.setStyle(.stroke(DesignStroke(color: DesignColor(255, 0, 0), width: 2)))
        let intents = StrokeJoin.allCases.map(StrokeIntent.join) + StrokeCap.allCases.map(StrokeIntent.cap)
        for intent in intents {
            #expect(w.strokeChange(intent) != nil, "\(intent) is enabled and does nothing")
        }
        for preset in [DashPreset.solid, .dashed, .dotted] {
            #expect(w.strokeChange(.dash(preset, pattern: nil)) != nil, "\(preset) is enabled and does nothing")
        }
        #expect(w.strokeStyleHelp == nil && w.strokeDashHelp == nil)
    }

    @Test func designColorClampsOutOfRangeAndNaN() {
        #expect(DesignColor(kernel: FillColor(r: 1.5, g: -0.2, b: .nan)) == DesignColor(255, 0, 0))
        for part in [Double.nan, -0.1, 1.2, 0.5, 0, 1] {
            let byte = UInt8(SampleRules.byte(part))
            #expect(DesignColor(kernel: FillColor(r: part, g: part, b: part)) == DesignColor(byte, byte, byte), "\(part)")
        }
    }

    @Test func kernelColorRoundTrips() {
        for color in [DesignColor(255, 0, 0), DesignColor(12, 128, 250), .shape, .black, .white] {
            #expect(DesignColor(kernel: color.kernelColor) == color)
        }
        #expect(DesignColor(0, 0, 255).kernelColor == FillColor(r: 0, g: 0, b: 1))
        let node = DesignNode(id: "n", name: "N", kind: .rectangle, frame: DesignRect(x: 0, y: 0, width: 10, height: 10))
        #expect(node.fill(in: node.frame.kernelRect) == .solid(node.fill.kernelColor))
    }

    @Test func eachCommandIsOneStepForTheSelection() throws {
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

    @Test func oneStepPerGesture() throws {
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

    @Test func aLockedLayerIsSkipped() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        w.toggleSelection("node-3")
        try w.setNodeLocked("node-2", true)
        #expect(Set(w.selectedNodeIDs) == ["node-2", "node-3"] && w.strokeHelp == nil, "locked A stays selected behind B")
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        #expect(Self.stroke(w, "node-3") != nil)
        #expect(Self.stroke(w, "node-2") == nil, "the locked layer took a stroke")
    }

    /// The catalog's schema refuses a width outside 0...1000, so the clamp is the editor's: its over-range width lands
    /// as the nearest bound on every selected layer (#4920).
    @Test func widthClamps() throws {
        var w = Self.threeSelected
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        for (width, landed) in [(5000.0, StrokeRules.widths.upperBound), (-3, StrokeRules.widths.lowerBound)] {
            let edit = try #require(w.strokeChange(.width(width, drag: nil)), "\(width) is refused, not clamped")
            try w.setStyle(edit.change)
            for id in ["node-2", "node-3", "node-4"] {
                #expect(Self.stroke(w, id)?.width == landed, "\(id) at \(width)")
            }
        }
    }

    /// The inspector's stroke edit skips a locked layer behind the primary, as the catalog does, and keeps it selected
    /// (#4919).
    @Test func theInspectorSkipsALockedLayerToo() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        w.toggleSelection("node-3")
        try w.setNodeLocked("node-2", true)
        let add = try #require(w.strokeChange(.add), "the editor is enabled")
        try w.setStyle(add.change)
        #expect(Self.stroke(w, "node-3") == .default)
        #expect(Self.stroke(w, "node-2") == nil, "the locked layer took a stroke")
        #expect(Set(w.selectedNodeIDs) == ["node-2", "node-3"])
    }

    /// A hidden layer takes no stroke from either path, and the editor says why (#4919).
    @Test func aHiddenLayerRefusesWithItsHelp() throws {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        try w.setNodeHidden("node-2", true)
        #expect(w.strokeHelp == "Show A to change it.")
        #expect(DesignWorkspace.catalog.availability("stroke.add", on: w) == .unavailable("Show A to change it."))
        #expect(throws: (any Error).self) { try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w) }
        #expect(throws: DesignRefusal.hidden("A")) { try w.setStyle(.stroke(.default)) }
        #expect(Self.stroke(w, "node-2") == nil)
        w.toggleSelection("node-3")
        #expect(w.strokeHelp == "Show A to change it.", "a hidden layer behind the primary refuses too")
    }

    @Test func trimIsUnavailableWithTheTrimHelp() throws {
        var w = Self.threeSelected
        _ = try DesignWorkspace.catalog.run("stroke.add", params: .object([:]), on: &w)
        #expect(DesignWorkspace.catalog.availability("stroke.trim", on: w)
            == .unavailable("Trim paths are for animation, in Flare and Halo."))
    }
}

@Suite struct DesignStrokeMigrationTests {
    /// A rectangle node as a file holds it, with `stroke` as the given JSON (or none).
    static func node(stroke: String?) -> String {
        let field = stroke.map { #","stroke":\#($0)"# } ?? ""
        return #"{"children":[],"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":100,"x":0,"y":0},"#
            + #""id":"node-2","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","text":""\#(field)}"#
    }

    static func decode(_ json: String) throws -> DesignNode {
        try JSONDecoder().decode(DesignNode.self, from: Data(json.utf8))
    }

    @Test func anOldStrokeKeepsItsColourAndWidth() throws {
        let old = try Self.decode(Self.node(stroke: #"{"color":{"red":255,"green":0,"blue":0},"width":3}"#))
        #expect(old.stroke == VectorStroke(color: FillColor(r: 1, g: 0, b: 0), width: 3))
        #expect(old.stroke?.join == .miter && old.stroke?.cap == .butt && old.stroke?.dash == [])
        let grey = try Self.decode(Self.node(stroke: #"{"color":{"red":51,"green":102,"blue":204},"width":0.5}"#))
        #expect(grey.stroke == DesignStroke(color: DesignColor(51, 102, 204), width: 0.5))
    }

    @Test func noStrokeStaysNone() throws {
        #expect(try Self.decode(Self.node(stroke: nil)).stroke == nil)
    }

    @Test func aSavedStrokeRoundTripsJoinCapAndDash() throws {
        let stroke = VectorStroke(color: FillColor(r: 0, g: 0.5, b: 1), width: 2, join: .round, cap: .round,
                                  dash: [8, 4], dashPhase: 2)
        let saved = DesignNode(id: "node-2", name: "A", kind: .rectangle,
                               frame: DesignRect(x: 0, y: 0, width: 100, height: 80), stroke: stroke)
        let opened = try JSONDecoder().decode(DesignNode.self, from: JSONEncoder().encode(saved))
        #expect(opened.stroke == stroke)
        #expect(opened == saved)
    }

    @Test func aNewStrokeInAFileDecodes() throws {
        let json = #"{"color":{"r":0,"g":0,"b":1,"a":1},"width":2,"join":"bevel","cap":"square","dash":[8,4]}"#
        let opened = try Self.decode(Self.node(stroke: json))
        #expect(opened.stroke == VectorStroke(color: FillColor(r: 0, g: 0, b: 1), width: 2, join: .bevel, cap: .square,
                                              dash: [8, 4]))
    }
}

/// The stroke lives in DesignNode's copy-on-write extras box (DesignNodeStackTests pins the node's size); it must
/// still behave as a value.
@Suite struct DesignStrokeBoxTests {
    @Test func aCopyKeepsItsOwnStroke() {
        let frame = DesignRect(x: 0, y: 0, width: 1, height: 1)
        var original = DesignNode(id: "a", name: "R", kind: .rectangle, frame: frame)
        #expect(original.stroke == nil)
        original.stroke = DesignStroke(color: .black, width: 3)
        var copy = original
        copy.stroke?.width = 5
        #expect(original.stroke?.width == 3)
        #expect(copy.stroke?.width == 5)
        #expect(DesignNode(id: "dup", copying: original).stroke == original.stroke)
        #expect(DesignNode(id: "s", name: "R", kind: .rectangle, frame: frame, stroke: original.stroke).stroke?.width == 3)
    }
}
