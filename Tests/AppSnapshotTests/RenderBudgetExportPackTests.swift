// RenderBudgetExportPackTests.swift (export-pack XP-5, quality rows "render: typing a 4-digit width" and "render:
// switching Size mode"): the gallery's `export-pack` page (GalleryExportPackPage, which owns the pick and is the
// window here) in a key-capable 1280 x 820 window, its body counter the window's. Typing: a click on the Size row's
// Width (`suite.export.size.width`) opens ScrubField's typing field, then 4 digits and Return each run the page's body
// at most 2 times (target: the digits 0, since the draft is the field's own state; Return 1, the commit). Mode switch:
// a click on the Long edge chip (`suite.export.size.mode.longEdge`) runs it at most 2 times (target 1). The test
// process is never the active app, so the root opts in to activation clicks (RenderBudgetHarness.swift). Nested in
// BodyCountSuites: it reads a global body counter. The snapshots are SuiteExportPackSnapshots. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetExportPackTests {
        /// The page's body runs; nil in release.
        static func bodies() -> Int? {
            #if DEBUG
            return GalleryExportPackPage.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func typingWidthInTwoBodies() async throws {
            let w = RenderBudgetWindow(GalleryExportPackPage().allowsWindowActivationEvents(), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            try await w.settle(untilStable: Self.bodies)
            let width = try #require(await w.element("suite.export.size.width"), "no Width field (suite.export.size.width)")
            // A click that doesn't move opens the typing field (ScrubField's scrub gesture), which asks for the keys.
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: width.midX, y: width.midY)) }
            try await w.settle()
            let field = try #require(
                RenderBudgetNewDocumentTests.fields(in: w.host).first { $0.isEditable && $0.convert($0.bounds, to: nil).intersects(width) },
                "clicking Width opened no typing field")
            w.window.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
            try await w.settle()
            let keys: [(String, UInt16)] = [("1", 18), ("2", 19), ("0", 29), ("0", 29), ("\r", 36)]
            for (characters, keyCode) in keys {
                let name = characters == "\r" ? "Return" : characters
                let step = try await w.measure("export-pack type width \(name)", bodies: Self.bodies) {
                    try await w.ticks(1) { _ in RenderBudgetNewDocumentTests.press(characters, keyCode: keyCode, in: w.window) }
                }
                expectBodies(step, atMost: 2, target: characters == "\r" ? 1 : 0)
            }
            #expect(w.label("suite.export.size.readout") == "1200 × 1500 px", "typing 1200 with the lock on didn't read 1200 × 1500 px")
        }

        @Test(.timeLimit(.minutes(2))) func modeSwitchInTwoBodies() async throws {
            let w = RenderBudgetWindow(GalleryExportPackPage().allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let chip = try #require(await w.element("suite.export.size.mode.longEdge"), "no Long edge chip (suite.export.size.mode.longEdge)")
            let step = try await w.measure("export-pack switch to Long edge", bodies: Self.bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: chip.midX, y: chip.midY)) }
            }
            #expect(await w.element("suite.export.size.longEdge") != nil, "the Long edge chip showed no Long Edge field")
            #expect(w.label("suite.export.size.readout") == "1080 × 1350 px", "switching kept no 1080 × 1350 px")
            expectBodies(step, atMost: 2, target: 1)
        }
    }
}
#endif
