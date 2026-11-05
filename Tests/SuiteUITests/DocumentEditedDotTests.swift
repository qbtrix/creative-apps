// DocumentEditedDotTests.swift (#2861): `.suiteDocumentEdited(_:)` on an offscreen
// window sets the window's edited dot (NSWindow.isDocumentEdited) when its view lands
// and on each change of the flag, and clears it again.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor @Observable private final class Dirty {
    var edited = true
}

private struct Edited: View {
    let dirty: Dirty
    var body: some View { Text("Poster").suiteDocumentEdited(dirty.edited) }
}

@MainActor @Suite struct DocumentEditedDotTests {
    @Test func theDotFollowsTheFlag() async throws {
        let dirty = Dirty()
        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 320, height: 240),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.orderOut(nil) }
        window.contentView = NSHostingView(rootView: Edited(dirty: dirty))
        window.orderFrontRegardless()
        #expect(await settles { window.isDocumentEdited }, "an edited document left the dot off")
        dirty.edited = false
        #expect(await settles { !window.isDocumentEdited }, "a saved document left the dot on")
        dirty.edited = true
        #expect(await settles { window.isDocumentEdited }, "a new edit didn't set the dot again")
    }

    /// Lets the main actor run until `condition` holds, at most two seconds.
    private func settles(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }
}
