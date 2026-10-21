// RenderBudgetStrokeEditorTests.swift (stroke-style SS-4, quality row "render: 120-sample width scrub on the gallery
// page"): what scrubbing the stroke's Width costs in a real 1280 x 820 window. The window hosts StrokeEditor the way
// the gallery's `stroke-editor` page does, its stroke in a child page that applies each intent
// (GalleryStrokeEditor.applied) and logs it, and counts the window's own bodies: 120 increments of
// `suite.stroke.width` (the way VoiceOver and XCUI adjust it) send 120 `stroke.width` intents and run at most 3
// window bodies (target 0: only the page and the editor redraw). The p95 (packet: ≤ 8 ms) is printed, not gated: a
// step-time budget belongs in a Tests/perf-suites.txt test. The trim-end scrub row waits on SS-9: the trim rows are
// disabled with StrokeRules.waitingCore until dash and trim run. Nested in BodyCountSuites: it reads a global body
// counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetStrokeEditorTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func widthScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(StrokeEditorBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return StrokeEditorBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            _ = try #require(await w.element("suite.stroke.width"), "the editor shows no Width row (suite.stroke.width)")
            let widths = StrokeEditorBudgetPage.widths
            let step = try await w.measure("stroke-editor Width scrub, \(Self.samples) steps", bodies: bodies) {
                let found = try await w.adjust("suite.stroke.width", steps: Self.samples)
                #expect(found, "Width can't be adjusted")
            }
            #expect(StrokeEditorBudgetPage.widths - widths == Self.samples,
                    "\(Self.samples) Width steps sent \(StrokeEditorBudgetPage.widths - widths) stroke.width intents")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the stroke.
private struct StrokeEditorBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Stroke").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            StrokeEditorBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's editor half on a 2 pt black stroke: each intent applied to the stroke and logged.
private struct StrokeEditorBudgetPage: View {
    // view-static: main-actor
    static var widths = 0
    @State private var stroke: VectorStroke? = GalleryStrokeEditor.start
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            InspectorSection("Stroke") {
                StrokeEditor(stroke: stroke, help: nil, dashHelp: StrokeRules.waitingCore) { intent in
                    if case .width = intent { Self.widths += 1 }
                    stroke = GalleryStrokeEditor.applied(intent, to: stroke)
                    log.append("\(intent.command.id) \(intent)")
                }
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}
#endif
