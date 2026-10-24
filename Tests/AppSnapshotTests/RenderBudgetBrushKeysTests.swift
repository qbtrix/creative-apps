// RenderBudgetBrushKeysTests.swift (brush-keys BK-6): ten `]` presses through a key-capable window step the gallery's
// fake brush from 20 px to 70 px in at most ten page bodies (GalleryBrushKeysPage.bodyRuns). macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetBrushKeysTests {
        static let presses = 10
        #if DEBUG
        static var bodyRuns: Int? { GalleryBrushKeysPage.bodyRuns }
        #else
        static var bodyRuns: Int? { nil }
        #endif

        @Test(.timeLimit(.minutes(2))) func tenBracketsInTenBodies() async throws {
            let w = RenderBudgetWindow(BrushKeysBudgetHost(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
            let bodies = { () -> Int? in Self.bodyRuns }
            try await w.settle(untilStable: bodies)
            let canvas = try #require(await w.element("suite.gallery.brush-canvas"), "no suite.gallery.brush-canvas")
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: canvas.midX, y: canvas.midY)) }
            try await w.settle(untilStable: bodies)
            let step = try await w.measure("brush-keys ] x \(Self.presses)", bodies: bodies) {
                try await w.ticks(Self.presses) { _ in Self.press("]", in: w.window) }
            }
            try await w.settle(untilStable: bodies)
            let status = w.label("suite.gallery.brush-status") ?? ""
            #expect(status.hasPrefix("Size 70 px"), "ten ] presses left the brush at \(status), not 70 px")
            // At most one body per press; target: one.
            expectBodies(step, atMost: Self.presses, target: Self.presses)
        }

        /// A key-down and key-up of `characters` sent through `window`, which hands them to its first responder.
        static func press(_ characters: String, in window: NSWindow) {
            for kind in [NSEvent.EventType.keyDown, .keyUp] {
                guard let event = NSEvent.keyEvent(
                    with: kind, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                    characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 30)
                else { Issue.record("no \(kind) event"); return }
                window.sendEvent(event)
            }
        }
    }
}

/// The window: the gallery's brush-keys page, taking the test's click while the test process is inactive.
private struct BrushKeysBudgetHost: View {
    var body: some View { GalleryBrushKeysPage().allowsWindowActivationEvents() }
}
#endif
