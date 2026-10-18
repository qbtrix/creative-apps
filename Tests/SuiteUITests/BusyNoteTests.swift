// BusyNoteTests.swift: SuiteUI's BusyNote, the one busy note every app shows:
// its fraction clamps (done in 0...total, total at least 1), a zero delay
// shows it at once, and a positive delay keeps it hidden until it passes
// (#1379: the delay's task must run while the note is hidden). macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct BusyNoteTests {
    @Test func theFractionClampsDoneAndTotal() {
        #expect(BusyNote("x", identifier: "x").fraction == nil)
        let row = BusyNote("Importing 3 of 27", identifier: "library.import.progress", fraction: (2, 27))
        #expect(row.fraction?.value == 2 && row.fraction?.total == 27)
        let empty = BusyNote("x", identifier: "x", fraction: (0, 0))
        #expect(empty.fraction?.value == 0 && empty.fraction?.total == 1)
        #expect(BusyNote("x", identifier: "x", fraction: (40, 27)).fraction?.value == 27)
        #expect(BusyNote("x", identifier: "x", fraction: (-3, 27)).fraction?.value == 0)
    }

    @Test func aZeroDelayShowsAtOnce() {
        for note in [BusyNote("Opening…", identifier: "o"), BusyNote("Importing", identifier: "i", fraction: (1, 4))] {
            let host = NSHostingView(rootView: note.frame(width: 600))
            host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize.height > 0)
        }
    }

    /// The window is ordered on screen (off to the side) so the note's `.task`
    /// starts, and the test awaits on the main actor while it sleeps.
    @Test(arguments: [false, true]) func aDelayHidesItUntilItPasses(bar: Bool) async throws {
        let note = BusyNote("Saving…", identifier: "s", fraction: bar ? (0, 24) : nil, delay: .milliseconds(10))
        let host = NSHostingView(rootView: note.frame(width: 600))
        host.frame = CGRect(x: 0, y: 0, width: 600, height: 200)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.height < 1, "the note showed before its delay")
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        defer { window.close() }
        for _ in 0..<100 where host.fittingSize.height <= 0 {
            try await Task.sleep(for: .milliseconds(20))
            host.layoutSubtreeIfNeeded()
        }
        #expect(host.fittingSize.height > 0, "the note never showed after its 10 ms delay")
    }
}
