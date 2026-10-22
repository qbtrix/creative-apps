// RenderBudgetNewDocumentTests.swift (document-setup DS-6's budget row): the gallery's `new-document` page in a
// key-capable 1280 x 820 window; a click into Width and 20 typed digits run the page's body at most once, since
// the form lives in the sheet's own state. The New Document snapshots sit beside it:
// suite-new-document-{light,dark}.png and suite-document-settings-{light,dark}.png. Nested in BodyCountSuites: it
// reads global body counters. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetNewDocumentTests {
        @Test(.timeLimit(.minutes(2))) func typeWidthInOneBody() async throws {
            let w = RenderBudgetWindow(GalleryNewDocumentPage().allowsWindowActivationEvents(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            let bodies = { () -> Int? in
                #if DEBUG
                return GalleryNewDocumentPage.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let width = try #require(await w.element("suite.newdoc.width"), "no Width field (suite.newdoc.width)")
            w.click(at: CGPoint(x: width.midX, y: width.midY))
            try await w.settle()
            let step = try await w.measure("new-document type width", bodies: bodies) {
                try await w.ticks(20) { _ in Self.press("1", keyCode: 18, in: w.window) }
            }
            expectBodies(step, atMost: 1, target: 0)
        }

        /// A key down and up for `characters`, sent straight to `window`.
        static func press(_ characters: String, keyCode: UInt16, in window: NSWindow) {
            for kind in [NSEvent.EventType.keyDown, .keyUp] {
                guard let event = NSEvent.keyEvent(
                    with: kind, location: .zero, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                    characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)
                else { Issue.record("no \(kind) event"); return }
                window.sendEvent(event)
            }
        }
    }
}

@MainActor @Suite struct SuiteNewDocumentSnapshots {
    @Test func screens() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryNewDocumentSheet(settings: false), name: "suite-new-document-\(scheme.name)", scheme: scheme)
            try snapshot(GalleryNewDocumentSheet(settings: true), name: "suite-document-settings-\(scheme.name)", scheme: scheme)
        }
    }
}
#endif
