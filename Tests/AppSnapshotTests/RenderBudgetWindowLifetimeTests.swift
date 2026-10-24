// RenderBudgetWindowLifetimeTests.swift: the harness's key-capable window opens, takes key, closes and is freed,
// ten times over, without AppKit throwing. A window made key-capable by swapping its class (the old
// RenderBudgetHistoryPanelTests route) is KVO-observed already, so freeing it threw NSRangeException
// ("_windowLayerContext") and killed the process, mid-way through whichever test ran next. The window is freed
// inside this test, so a regression crashes here, not in a neighbour. scripts/ci's isa-swizzle lint keeps the
// swap out. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@MainActor @Suite struct RenderBudgetWindowLifetimeTests {
    @Test(.timeLimit(.minutes(3))) func keyCapableWindowsAreFreedCleanly() async throws {
        for round in 0..<10 {
            weak var freed: NSWindow?
            do {
                // Each AppKit call in its own pool, so what it autoreleases is let go when the call returns,
                // not when the test's own pool drains after the last round.
                let w = autoreleasepool { RenderBudgetWindow(Text("round \(round)"), keyCapable: true) }
                freed = w.window
                autoreleasepool { w.window.makeKey() }
                #expect(w.window.canBecomeKey)
                try await w.settle(20)
                autoreleasepool { w.close() }
            }
            // AppKit drops its last references to a closed window a few run-loop turns later (2 to 4 here):
            // turn the run loop, each turn in its own pool, until the window is freed. On a loaded Mac one
            // turn can take seconds, so a wall-clock deadline alone ran out before the turn that frees it
            // (#5033): call it leaked only after 5 s AND 50 turns. A window something really keeps alive
            // still fails below.
            let deadline = Date().addingTimeInterval(5)
            var turns = 0
            while freed != nil, Date() < deadline || turns < 50 {
                autoreleasepool { _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01)) }
                await Task.yield()
                turns += 1
            }
            #expect(freed == nil, "round \(round): the closed window is still alive after 5 s and \(turns) run-loop turns, so it leaked")
        }
    }
}
#endif
