// DesignHistoryCommandTests.swift (design/autosave-history DA-6): the History panel's two commands in Design's
// catalog. `history.read` lists the base, every step and where the document is; `history.jump` lands there through
// the workspace's own jump, records no step, refuses out of range and is off with no steps. RJ-D33
// (Tests/RealJobs/design/history-jump) moves one card 30 times, jumps to step 20 and saves: the card sits where
// the 20th move left it. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignHistoryCommandTests {
    /// The cards fixture with node-2 nudged right `count` times, each nudge its own step.
    static func nudged(_ count: Int) throws -> DesignWorkspace {
        var w = DesignFixtures.cards
        for _ in 0..<count {
            _ = try DesignWorkspace.catalog.run("edit.select", params: .object(["ids": .array([.string("node-2")])]), on: &w)
            _ = try DesignWorkspace.catalog.run("object.nudge", params: .object(["direction": .string("right")]), on: &w)
        }
        return w
    }

    @Test func bothSpecsAreListed() {
        #expect(DesignWorkspace.catalog.ids.contains("history.read"))
        #expect(DesignWorkspace.catalog.ids.contains("history.jump"))
        #expect(DesignHeadless.catalog.ids.contains("history.jump"))
    }

    @Test func readListsEveryStep() throws {
        var w = try Self.nudged(3)
        let result = try DesignWorkspace.catalog.run("history.read", params: .object([:]), on: &w).result
        guard case .object(let listing) = result, case .array(let steps)? = listing["steps"] else {
            Issue.record("no steps in \(result)"); return
        }
        #expect(steps == Array(repeating: .string("Nudge"), count: 3))
        #expect(listing["index"] == .number(3))
    }

    @Test func jumpLandsWithoutAStep() throws {
        var w = try Self.nudged(5)
        let x = try #require(DesignFixtures.cards.frame("node-2")?.x)
        let outcome = try DesignWorkspace.catalog.run("history.jump", params: .object(["index": .number(2)]), on: &w)
        #expect(outcome.undoStep == nil)
        #expect(w.frame("node-2")?.x == x + 2)
        #expect(w.historyListing.index == 2 && w.historyListing.steps.count == 5)
        #expect(throws: CatalogError.self) {
            try DesignWorkspace.catalog.run("history.jump", params: .object(["index": .number(6)]), on: &w)
        }
        #expect(w.historyListing.index == 2)
    }

    @Test func jumpIsOffWithNoSteps() {
        #expect(DesignWorkspace.catalog.availability("history.jump", on: DesignFixtures.cards).why == "There are no steps yet.")
    }

    @Test func realJobHistoryJumpPasses() throws {
        let problems = try DesignJob.check("history-jump")
        #expect(problems == [], "\(problems)")
    }
}
