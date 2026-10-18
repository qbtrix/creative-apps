// NudgeMarqueeTests.swift: the checks for `Nudge` and `Marquee` (editor-kernel
// EK-9, slice EK-sel), written from the packet before the code: the one delta
// rule (1 a press, 10 with Shift, any custom step), the run key a nudge run
// folds under, the marquee rect from two corners and the union rule, plus
// KJ2's nudge and marquee half. EK-10 added Selection/Nudge.swift and
// Selection/Marquee.swift and turned these on (lead.md rule 13). The
// mutation table names largeIsTen and unionDedupes.
import Testing
import SuiteKernel

@Suite struct NudgeMarqueeTests {
    @Test func smallIsOnePoint() {
        #expect(Nudge.delta(.left, large: false) == Point(x: -1, y: 0))
        #expect(Nudge.delta(.right, large: false) == Point(x: 1, y: 0))
        #expect(Nudge.delta(.up, large: false) == Point(x: 0, y: -1))
        #expect(Nudge.delta(.down, large: false) == Point(x: 0, y: 1))
    }

    @Test func largeIsTen() {
        #expect(Nudge.delta(.left, large: true) == Point(x: -10, y: 0))
        #expect(Nudge.delta(.right, large: true) == Point(x: 10, y: 0))
        #expect(Nudge.delta(.up, large: true) == Point(x: 0, y: -10))
        #expect(Nudge.delta(.down, large: true) == Point(x: 0, y: 10))
    }

    @Test func customSteps() {
        // A pixel grid or a timeline passes its own steps; the rule stays one.
        #expect(Nudge.delta(.right, large: false, step: 0.5, largeStep: 8) == Point(x: 0.5, y: 0))
        #expect(Nudge.delta(.up, large: true, step: 0.5, largeStep: 8) == Point(x: 0, y: -8))
    }

    @Test func runKeyNamesTheBaseAndTheIDs() {
        let key = Nudge.runKey("nudge", ["a", "b"])
        // Stable: the same press on the same selection folds into one step.
        #expect(key == Nudge.runKey("nudge", ["a", "b"]))
        #expect(key.hasPrefix("nudge"))
        // A different selection or a different edit starts a new run.
        #expect(key != Nudge.runKey("nudge", ["a"]))
        #expect(key != Nudge.runKey("nudge", ["a", "c"]))
        #expect(key != Nudge.runKey("move", ["a", "b"]))
    }

    @Test func rectEnclosesEitherCornerOrder() {
        let down = Marquee.rect(enclosing: Point(x: 10, y: 20), Point(x: 110, y: 70))
        let up = Marquee.rect(enclosing: Point(x: 110, y: 70), Point(x: 10, y: 20))
        #expect(down == up)
        #expect(down.minX == 10 && down.minY == 20 && down.maxX == 110 && down.maxY == 70)
        let crossed = Marquee.rect(enclosing: Point(x: 110, y: 20), Point(x: 10, y: 70))
        #expect(crossed == down)
        let point = Marquee.rect(enclosing: Point(x: 5, y: 5), Point(x: 5, y: 5))
        #expect(point.width == 0 && point.height == 0)
    }

    @Test func unionReplacesWithoutShift() {
        #expect(Marquee.union(["a", "b"], ["c", "d"], extending: false) == ["c", "d"])
        #expect(Marquee.union(["a"], [String](), extending: false).isEmpty)
    }

    @Test func unionDedupes() {
        // With Shift the found items join after the selection, each id once.
        #expect(Marquee.union(["a", "b"], ["b", "c"], extending: true) == ["a", "b", "c"])
        #expect(Marquee.union(["a"], ["c", "c", "a"], extending: true) == ["a", "c"])
        #expect(Marquee.union([String](), ["d", "d"], extending: false) == ["d"])
    }

    /// KJ2, the nudge and marquee walk: drag a marquee over the cards, Shift-drag
    /// a second, then nudge the selection three times under one run key.
    @Test func nudgeMarqueeWalk() {
        let area = Marquee.rect(enclosing: Point(x: 320, y: 220), Point(x: 90, y: 90))
        #expect(area.minX == 90 && area.maxY == 220)
        var picked = Marquee.union([String](), ["a", "b"], extending: false)
        picked = Marquee.union(picked, ["b", "c"], extending: true)
        #expect(picked == ["a", "b", "c"])
        var total = Point(x: 0, y: 0)
        var keys: Set<String> = []
        for large in [false, false, true] {
            let d = Nudge.delta(.right, large: large)
            total = Point(x: total.x + d.x, y: total.y + d.y)
            keys.insert(Nudge.runKey("nudge", picked))
        }
        #expect(total == Point(x: 12, y: 0))
        #expect(keys.count == 1)
    }
}
