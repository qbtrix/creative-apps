// CoalesceKeyTests.swift: the checks for `CoalesceKey`, the one key a drag's
// samples record under in every app (#5335). The key is pinned for a drag
// over two targets; target order doesn't matter; a different property, target
// set or token starts a new step; a gesture keeps the token its first sample
// minted. The mutation plan SuiteKernel.CoalesceKey names the sort and the token.
import Testing
import SuiteKernel

@Suite struct CoalesceKeyTests {
    @Test func pinsTheKeyForADragOverTwoTargets() {
        #expect(CoalesceKey.key("fill", on: ["b", "a"], drag: "t1") == "fill\u{1E}a\u{1F}b\u{1E}t1")
    }

    @Test func targetOrderDoesNotMatter() {
        #expect(CoalesceKey.key("stroke", on: ["a", "b"], drag: "t") == CoalesceKey.key("stroke", on: ["b", "a"], drag: "t"))
    }

    @Test func aNewPropertyTargetSetOrTokenIsANewStep() {
        let key = CoalesceKey.key("fill", on: ["a", "b"], drag: "t1")
        #expect(key != CoalesceKey.key("stroke", on: ["a", "b"], drag: "t1"))
        #expect(key != CoalesceKey.key("fill", on: ["a"], drag: "t1"))
        #expect(key != CoalesceKey.key("fill", on: ["a", "c"], drag: "t1"))
        #expect(key != CoalesceKey.key("fill", on: ["a", "b"], drag: "t2"))
        #expect(key != CoalesceKey.key("fill", on: ["a", "b"]))
    }

    @Test func aRunWithNoDragIsThePropertyAndTargets() {
        #expect(CoalesceKey.key("nudge", on: ["a"]) == "nudge\u{1E}a")
        #expect(Nudge.runKey("nudge", ["a"]) == CoalesceKey.key("nudge", on: ["a"]))
    }

    @Test func aGestureKeepsItsFirstToken() {
        let first = CoalesceKey.token(nil)
        #expect(!first.isEmpty)
        #expect(CoalesceKey.token(first) == first)
        #expect(CoalesceKey.token(nil) != first)
    }
}
