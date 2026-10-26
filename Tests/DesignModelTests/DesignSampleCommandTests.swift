// DesignSampleCommandTests.swift (eyedropper DY-6): `color.sample` (SuiteKernel's query) and Design's own
// `color.pick {x, y, to}` in Design's catalog. The sample reads the topmost visible layer at the point, never the
// selection; a pick samples and applies in one step, onto the fill or the stroke. RJ-D34
// (Tests/RealJobs/design/pick-fill) samples a red ellipse over a white rectangle, selects the rectangle, picks at
// the same point and saves: the rectangle's fill is red. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSampleCommandTests {
    static func point(_ x: Double, _ y: Double, to: String? = nil) -> JSONValue {
        var params: [String: JSONValue] = ["x": .number(x), "y": .number(y)]
        if let to { params["to"] = .string(to) }
        return .object(params)
    }

    @Test func bothSpecsAreListed() {
        #expect(DesignWorkspace.catalog.ids.contains("color.sample"))
        #expect(DesignWorkspace.catalog.ids.contains("color.pick"))
        #expect(DesignHeadless.catalog.ids.contains("color.pick"))
    }

    /// The trap: node-2 is selected, but the ellipse on top is what the sample reads.
    @Test func sampleReadsTheTopmostLayer() throws {
        var w = try DesignSampleTests.shapes()
        let result = try DesignWorkspace.catalog.run("color.sample", params: Self.point(250, 250), on: &w).result
        guard case .object(let fields) = result, case .object(let color)? = fields["color"] else {
            Issue.record("no colour in \(result)"); return
        }
        #expect(color["hex"] == .string("#FF0000"))
        let empty = try DesignWorkspace.catalog.run("color.sample", params: Self.point(2000, 2000), on: &w).result
        #expect(empty == .object(["color": .null]))
    }

    @Test func pickSetsTheFillInOneStep() throws {
        var w = try DesignSampleTests.shapes()
        let outcome = try DesignWorkspace.catalog.run("color.pick", params: Self.point(350, 350, to: "fill"), on: &w)
        #expect(outcome.undoStep == "Fill")
        #expect(w.treeNode("node-2")?.fill == DesignColor(255, 0, 0))
        w.undo()
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape)
    }

    @Test func pickSetsTheStroke() throws {
        var w = try DesignSampleTests.shapes()
        let outcome = try DesignWorkspace.catalog.run("color.pick", params: Self.point(350, 350, to: "stroke"), on: &w)
        #expect(outcome.undoStep == "Stroke")
        #expect(w.treeNode("node-2")?.stroke == DesignStroke(color: DesignColor(255, 0, 0), width: 1))
        #expect(w.treeNode("node-2")?.fill == DesignColor.shape)
    }

    @Test func pickIsOffWithNothingSelected() throws {
        var w = try DesignSampleTests.shapes()
        w.deselect()
        #expect(DesignWorkspace.catalog.availability("color.pick", on: w).why != nil)
        #expect(DesignWorkspace.catalog.availability("color.pick", on: DesignWorkspace()).why == "Open a design first.")
    }

    @Test func realJobPickFillPasses() throws {
        let problems = try DesignJob.check("pick-fill")
        #expect(problems == [], "\(problems)")
    }
}
