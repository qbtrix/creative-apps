// SuiteOpenQueueTests.swift: SuiteOpenQueue, the files waiting for an app's
// window. An empty window takes a file in place (once: it isn't empty while
// that file opens), else a new window is asked for and takes the oldest
// waiting file when it appears; the first window also asks for one per file
// that came before any window could.
import Foundation
import SuiteUI
import Testing

@MainActor struct SuiteOpenQueueTests {
    private let a = URL(fileURLWithPath: "/t/A.flare")
    private let b = URL(fileURLWithPath: "/t/B.flare")

    @Test func anEmptyWindowTakesTheFileInPlace() {
        let queue = SuiteOpenQueue(windowID: "t")
        var asked = 0
        var opened: [URL] = []
        #expect(queue.windowAppeared(requestWindow: { asked += 1 }) == nil)
        let window = UUID()
        queue.setEmpty(window, open: { opened.append($0) })
        queue.open(a)
        #expect(opened == [a])
        #expect(asked == 0)
        // It is opening A now, so B asks for a window of its own.
        queue.open(b)
        #expect(opened == [a])
        #expect(asked == 1)
        #expect(queue.windowAppeared(requestWindow: { asked += 1 }) == b)
    }

    @Test func aWindowWithADocumentAsksForANewWindow() {
        let queue = SuiteOpenQueue(windowID: "t")
        var asked = 0
        _ = queue.windowAppeared(requestWindow: { asked += 1 })
        let window = UUID()
        queue.setEmpty(window, open: { _ in Issue.record("a full window took the file") })
        queue.setEmpty(window, open: nil)
        queue.open(a)
        #expect(asked == 1)
        #expect(queue.windowAppeared(requestWindow: { asked += 1 }) == a)
    }

    @Test func filesBeforeAnyWindowWaitForTheFirstOne() {
        let queue = SuiteOpenQueue(windowID: "t")
        queue.open(a)
        queue.open(b)
        var asked = 0
        #expect(queue.windowAppeared(requestWindow: { asked += 1 }) == a)
        #expect(asked == 1)
        #expect(queue.windowAppeared(requestWindow: { asked += 1 }) == b)
        #expect(asked == 1)
    }
}
