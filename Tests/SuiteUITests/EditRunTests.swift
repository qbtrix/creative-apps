// EditRunTests.swift: one gesture, one end (QB-F3). A run opens with its
// first change, ends exactly once, and an end with no change never counts.
// Mutating calls go into a local first: #expect can't call a mutating member.
// No SwiftUI here. macOS only.
import SuiteUI
import Testing

@Test func changeOpensTheRunOnce() {
    var run = EditRun()
    let first = run.change()
    let second = run.change()
    let third = run.change()
    #expect(first)
    #expect(!second && !third)
    #expect(run.isOpen)
}

@Test func endClosesEachRunExactlyOnce() {
    var run = EditRun()
    _ = run.change()
    let first = run.end()
    let second = run.end()
    #expect(first)
    #expect(!second)
    #expect(run.ends == 1)
    #expect(!run.isOpen)
}

@Test func endWithNoChangeIsIgnored() {
    var run = EditRun()
    let ended = run.end()
    #expect(!ended)
    #expect(run.ends == 0)
    #expect(run == EditRun())
}

@Test func threeDragLikeRunsGiveThreeEnds() {
    var run = EditRun()
    var opened = 0
    var closed = 0
    for _ in 0..<3 {
        for _ in 0..<5 where run.change() { opened += 1 }
        if run.end() { closed += 1 }
        if run.end() { closed += 1 }
    }
    #expect(opened == 3)
    #expect(closed == 3)
    #expect(run.ends == 3)
}
