// HaloHistoryCommandIDTests.swift (autosave-history HA-6): Halo's catalog lists
// the kernel's `history.read` and `history.jump`, headless too; a jump through
// the catalog lands on its step and records none; and RJ-H33
// (`Tests/RealJobs/halo/history-jump/`) animates a solid's x, sets it at frames
// 0 to 9, jumps to four applied steps, saves and reopens to the four keys of
// those steps with their values and easings. Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloHistoryCommandIDTests {
    static let job = HaloJob.root.appendingPathComponent("history-jump")

    /// RJ-H33's input, opened headless, with the job's steps run on it through
    /// the headless catalog, its last (the jump) left out when `jump` is false.
    static func edited(jump: Bool) throws -> HaloHeadless {
        let input = try Data(contentsOf: job.appendingPathComponent("input/one-solid.halo"))
        var doc = try HaloHeadless.open(input, name: "one-solid.halo")
        let script = try JSONDecoder().decode(HaloJob.Script.self, from: Data(contentsOf: job.appendingPathComponent("history-jump.jobs.json")))
        for step in jump ? script.steps : script.steps.dropLast() {
            _ = try HaloHeadless.catalog.run(step.id, params: step.params, on: &doc)
        }
        return doc
    }

    @Test func theHistoryCommandsAreListed() throws {
        for id in ["history.jump", "history.read"] {
            #expect(HaloProject.catalog.ids.contains(id), "\(id)")
            #expect(HaloHeadless.catalog.ids.contains(id), "\(id)")
        }
        #expect(HaloProject.catalog.spec("history.jump")?.kind == .view)
        #expect(HaloProject.catalog.spec("history.read")?.kind == .query)
    }

    @Test func aJumpThroughTheCatalogLandsAndRecordsNothing() throws {
        var doc = try Self.edited(jump: false)
        let before = doc.workspace.historyListing
        #expect(before.steps.count == 11 && before.index == 11)
        let read = try HaloHeadless.catalog.run("history.read", params: .object([:]), on: &doc).result
        #expect(read == (try JSONValue(encoding: before)))
        _ = try HaloHeadless.catalog.run("history.jump", params: .object(["index": .number(4)]), on: &doc)
        let after = doc.workspace.historyListing
        #expect(after.index == 4 && after.steps == before.steps)
        #expect(doc.workspace.history.undo.count == 4 && doc.workspace.history.redo.count == 7)
        #expect(doc.workspace.file.unsaved)
        #expect(throws: CatalogError.self) {
            try HaloHeadless.catalog.run("history.jump", params: .object(["index": .number(12)]), on: &doc)
        }
        #expect(doc.workspace.historyListing == after)
    }

    @Test func theJumpJobPassesAndReopensToFourKeys() throws {
        #expect(try HaloJob.check("history-jump") == [])
        let saved = try Self.edited(jump: true).save()
        let reopened = try HaloHeadless.open(saved, name: "one-solid.halo")
        let layer = try #require(reopened.workspace.selectedComposition?.layers.first)
        let keys = try #require(layer.tracks["x"])
        #expect(keys.map(\.frame) == [0, 1, 2, 23])
        #expect(keys.map(\.value) == [10, 15, 20, 0])
        #expect(keys.allSatisfy { $0.easing == .linear })
    }
}
