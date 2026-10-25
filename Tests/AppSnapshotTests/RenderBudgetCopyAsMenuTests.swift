// RenderBudgetCopyAsMenuTests.swift (clipboard-interop CB-u2): the gallery's
// `menu-command` page, whose Edit menu holds Copy As and Paste as Image
// (CopyAsMenu), in a 1280 x 820 window. Opening the menu re-reads the page's
// clip document; the hosted window has no menu bar and a pull-down's tracking
// loop would hold the test, so this measures what opening it costs the page:
// building the menu's items reads the document and runs no page body, and the
// one change the menu reflects (Copy Text, which puts text on the fake
// pasteboard and turns Paste as Image off) runs at most 2 page bodies
// (target 1). The journey proves the items show. Nested in BodyCountSuites: it
// reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetCopyAsMenuTests {
        @Test(.timeLimit(.minutes(2))) func openMenuInOneBody() async throws {
            let w = RenderBudgetWindow(GalleryMenuCommandPage())
            defer { w.close() }
            try await w.settle(600)
            let bodies = { () -> Int? in
                #if DEBUG
                return GalleryMenuCommandPage.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)

            // Opening the menu builds its items from the document: no page body.
            let open = try await w.measure("copy-as menu open", bodies: bodies) {
                try await w.ticks(1) { _ in
                    let menu = CopyAsMenu(on: GalleryClipDocument(), ownTitle: "Gallery Layers", copy: { _ in }, pasteAsImage: {})
                    _ = menu.copyItems.count + (menu.pasteItem == nil ? 0 : 1)
                }
            }
            expectBodies(open, atMost: 0, target: 0)

            // Copy Text changes what the menu shows: one page body.
            let copyText = try #require(await w.element("suite.gallery.menu-command.copy-text"), "no Copy Text")
            let step = try await w.measure("copy-as copy text", bodies: bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: copyText.midX, y: copyText.midY)) }
            }
            expectBodies(step, atMost: 2, target: 1)
        }
    }
}
#endif
