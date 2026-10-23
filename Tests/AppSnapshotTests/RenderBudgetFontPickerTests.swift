// RenderBudgetFontPickerTests.swift (font-picker FP-4): what typing a query
// costs the font picker's gallery page (Tests/render-budgets.md: ≤ 2 window
// bodies per keystroke), through the harness (RenderBudgetHarness.swift), on
// 500 families. It types "gro" into the search field's editor one character
// per 1/120 s. The query is the picker's own state, so a keystroke runs no page
// body (target 0) and at most two picker bodies. The step time is printed, not
// gated (perf-nightly owns timing). Nested in BodyCountSuites, as every suite
// that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFontPickerTests {
        static let typed = "gro"

        /// 500 families, Regular and Bold each: Grotesk 0, Serif 1, Mono 2, Sans 3, Slab 4, Grotesk 5, ...
        static let families: [FontFamily] = (0..<500).map { i in
            let stems = ["Grotesk", "Serif", "Mono", "Sans", "Slab"]
            return FontFamily(name: "\(stems[i % stems.count]) \(i)", faces: [
                FontFace(name: "Regular", weight: 400, italic: false), FontFace(name: "Bold", weight: 700, italic: false),
            ])
        }

        @Test(.timeLimit(.minutes(2))) func typingFiltersInTwoBodies() async throws {
            let page = GalleryFontPickerPage(families: Self.families)
            let w = RenderBudgetWindow(page, size: CGSize(width: 640, height: 720), keyCapable: true)
            defer { w.close() }
            let pageBodies = { () -> Int? in
                #if DEBUG
                return GalleryFontPickerPage.bodyRuns
                #else
                return nil
                #endif
            }
            let pickerBodies = { () -> Int? in
                #if DEBUG
                return FontPicker.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: pageBodies)
            for id in ["suite.fontpicker.search", "suite.fontpicker.face", "suite.fontpicker.size", "suite.fontpicker.family.Grotesk 0"] {
                #expect(await w.element(id) != nil, "no \(id)")
            }

            let editor = try #require(try await Self.edit("suite.fontpicker.search", in: w), "the search field didn't start editing")
            let pickerBefore = pickerBodies()
            let typing = try await w.measure("font picker search, \(Self.typed.count) keystrokes", bodies: pageBodies) {
                let keys = Array(Self.typed)
                try await w.ticks(keys.count) { i in
                    editor.insertText(String(keys[i - 1]), replacementRange: editor.selectedRange())
                }
            }
            expectBodies(typing, atMost: 2 * Self.typed.count, target: 0)
            if let before = pickerBefore, let after = pickerBodies() {
                #expect(after - before <= 2 * Self.typed.count, "the picker ran \(after - before) bodies for \(Self.typed.count) keystrokes")
                #expect(after > before, "typing ran no picker body: the query didn't reach the list")
            }
            print("font picker search p95: \(typing.p95) ms over \(typing.steps) steps")
        }

        /// The NSTextField under the element `identifier`, made first responder; its field editor.
        static func edit(_ identifier: String, in w: RenderBudgetWindow<GalleryFontPickerPage>) async throws -> NSTextView? {
            func fields(in view: NSView) -> [NSTextField] {
                (view as? NSTextField).map { [$0] } ?? view.subviews.flatMap(fields)
            }
            guard let frame = await w.element(identifier),
                let field = fields(in: w.host).first(where: {
                    $0.isEditable && $0.convert($0.bounds, to: nil).intersects(frame)
                })
            else { return nil }
            w.window.makeKey()
            w.window.makeFirstResponder(field)
            try await w.settle(200)
            return w.window.firstResponder as? NSTextView
        }
    }
}
#endif
