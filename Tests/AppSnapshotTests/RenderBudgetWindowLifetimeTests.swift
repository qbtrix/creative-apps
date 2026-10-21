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
    @Test(.timeLimit(.minutes(1))) func keyCapableWindowsAreFreedCleanly() async throws {
        for round in 0..<10 {
            weak var freed: NSWindow?
            do {
                let w = RenderBudgetWindow(Text("round \(round)"), keyCapable: true)
                freed = w.window
                w.window.makeKey()
                #expect(w.window.canBecomeKey)
                try await w.settle(20)
                w.close()
            }
            for _ in 0..<100 where freed != nil { try await Task.sleep(for: .milliseconds(10)) }
            #expect(freed == nil, "round \(round): the closed window is still alive, so its teardown went untested")
        }
    }
}
#endif
