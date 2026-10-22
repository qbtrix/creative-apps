// RenderBudgetHelpTests.swift (report-problem RP-3): what typing a note costs the Report a Problem sheet
// (Tests/render-budgets.md: ≤ 2 window bodies per keystroke), through the harness (RenderBudgetHarness.swift),
// on a fixed report. It checks every control carries its `suite.help.report.<control>` id, types five
// characters into the note field's editor one per 1/120 s, then clicks Copy: the copied text is the
// report's text with the typed note. The sheet's own body is the window body: the note lives in its own
// field view, so a keystroke runs none (target 0). Nested in BodyCountSuites, as every suite that reads a
// body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHelpTests {
        static let report = ProblemReport(
            app: "Photo", version: "1.0", build: "42", macOS: "Version 27.0 (Build 27A100)", model: "Mac15,3", crashes: [])
        static let typed = "Hello"

        @Test(.timeLimit(.minutes(2))) func typeNoteInTwoBodiesEach() async throws {
            let copied = Copied()
            let sheet = ProblemReportSheet(report: Self.report, onCopy: { copied.texts.append($0) }, onClose: {})
            let w = RenderBudgetWindow(sheet, size: CGSize(width: 640, height: 560), keyCapable: true)
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return ProblemReportSheet.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            for control in ProblemReportSheet.controls {
                #expect(await w.element(ProblemReportSheet.identifier(control)) != nil, "no suite.help.report.\(control)")
            }

            let editor = try #require(try await Self.edit(ProblemReportSheet.identifier("note"), in: w), "the note field didn't start editing")
            let typing = try await w.measure("report sheet note, \(Self.typed.count) keystrokes", bodies: bodies) {
                let keys = Array(Self.typed)
                try await w.ticks(keys.count) { i in
                    editor.insertText(String(keys[i - 1]), replacementRange: editor.selectedRange())
                }
            }
            expectBodies(typing, atMost: 2 * Self.typed.count, target: 0)

            let copy = try #require(await w.element(ProblemReportSheet.identifier("copy")), "no Copy")
            w.window.makeFirstResponder(nil)
            try await w.settle(200)
            w.click(at: CGPoint(x: copy.midX, y: copy.midY))
            try await w.settle(200)
            #expect(copied.texts == [Self.report.text(note: Self.typed)], "Copy copied \(copied.texts)")
        }

        /// The NSTextField under the element `identifier`, made first responder; its field editor.
        static func edit(_ identifier: String, in w: RenderBudgetWindow<ProblemReportSheet>) async throws -> NSTextView? {
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

/// What Copy handed over, in order.
@MainActor private final class Copied {
    var texts: [String] = []
}
#endif
