// HaloTransformCommandIDTests.swift (transform HT-6): Halo's catalog lists the
// kernel's six `transform.*` commands, headless too; Flip is refused with
// Halo's sentence; and RJ-H34 (`Tests/RealJobs/halo/key-turn/`) animates a
// shape's Rotation and Scale, turns it 30 degrees and doubles it about its
// centre at frame 12, saves and reopens to keys at 12 over the base values at
// 0, the centre where it was. Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloTransformCommandIDTests {
    static let job = HaloJob.root.appendingPathComponent("key-turn")
    static let ids = ["transform.flip", "transform.read", "transform.reset", "transform.rotate", "transform.scale", "transform.set"]

    /// RJ-H34's input, opened headless, with the job's steps run through the headless catalog.
    static func edited() throws -> HaloHeadless {
        let input = try Data(contentsOf: job.appendingPathComponent("input/one-shape.halo"))
        var doc = try HaloHeadless.open(input, name: "one-shape.halo")
        let script = try JSONDecoder().decode(HaloJob.Script.self, from: Data(contentsOf: job.appendingPathComponent("key-turn.jobs.json")))
        for step in script.steps { _ = try HaloHeadless.catalog.run(step.id, params: step.params, on: &doc) }
        return doc
    }

    @Test func theTransformCommandsAreListed() {
        for id in Self.ids {
            #expect(HaloProject.catalog.ids.contains(id), "\(id)")
            #expect(HaloHeadless.catalog.ids.contains(id), "\(id)")
        }
        #expect(HaloProject.catalog.spec("transform.read")?.kind == .query)
        #expect(HaloProject.catalog.spec("transform.rotate")?.kind == .edit)
    }

    @Test func flipIsRefusedWithHalosSentence() throws {
        var doc = try Self.edited()
        let before = try doc.save()
        #expect(HaloHeadless.catalog.availability("transform.flip", on: doc).why == "Flipping isn't in Halo yet.")
        #expect(throws: CatalogError.self) {
            try HaloHeadless.catalog.run("transform.flip", params: .object(["axis": .string("horizontal")]), on: &doc)
        }
        #expect(try doc.save() == before)
        let empty = HaloProject(services: .fake)
        #expect(HaloProject.catalog.availability("transform.rotate", on: empty).why == "Select a layer to transform.")
    }

    @Test func theKeyTurnJobPassesAndReopensKeyedAtTwelve() throws {
        #expect(try HaloJob.check("key-turn") == [])
        let reopened = try HaloHeadless.open(try Self.edited().save(), name: "one-shape.halo")
        let layer = try #require(reopened.workspace.selectedComposition?.layers.first)
        let turn = try #require(layer.tracks["rotation"])
        #expect(turn.map(\.frame) == [0, 12] && turn.map(\.value) == [0, 30])
        for p in ["scaleX", "scaleY"] {
            let keys = try #require(layer.tracks[p], "\(p)")
            #expect(keys.map(\.frame) == [0, 12] && keys.map(\.value) == [1, 2], "\(p)")
        }
        let box = try #require(reopened.workspace.transformSelection)
        #expect((box.box.minX + box.box.maxX) / 2 == 130 && (box.box.minY + box.box.maxY) / 2 == 80)
    }
}
