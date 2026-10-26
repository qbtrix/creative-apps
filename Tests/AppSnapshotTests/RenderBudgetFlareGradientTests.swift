// RenderBudgetFlareGradientTests.swift (gradient-fill FG-3, Checks row FG-3): what dragging a gradient stop in
// Flare's FILL section costs in a real 1280 x 820 window. The window hosts FlareInspectorFill on a three-stop linear
// fill, the fill in a child page that applies each `.runFill` intent through the kernel's rules
// (GalleryGradientEditor.applied) and logs it, and counts the window's own bodies: 40 increments of the middle stop
// (`suite.gradient.stop.1`, the way VoiceOver and XCUI adjust it: the stop bar's drag ignores the test's
// window-activation clicks) send 40 `move` intents and run at most 3 window bodies (target 0: only the page and the
// section redraw). The p95 is printed, not gated: a step-time budget belongs in a Tests/perf-suites.txt test.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SuiteKernel
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareGradientTests {
        /// 1% each: the middle stop goes from 50% to 90%, never past the last stop.
        static let samples = 40

        @Test(.timeLimit(.minutes(2))) func stopDragInThreeBodies() async throws {
            let w = RenderBudgetWindow(FlareGradientBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareGradientBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(500)
            _ = try #require(await w.element("suite.gradient.stop.1"), "FILL shows no middle stop (suite.gradient.stop.1)")
            let moves = FlareGradientBudgetPage.moves
            let step = try await w.measure("flare FILL stop drag, \(Self.samples) steps", bodies: bodies) {
                let found = try await w.adjust("suite.gradient.stop.1", steps: Self.samples)
                #expect(found, "the middle stop can't be adjusted")
            }
            #expect(FlareGradientBudgetPage.moves - moves == Self.samples,
                    "\(Self.samples) stop steps sent \(FlareGradientBudgetPage.moves - moves) move intents")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the fill.
private struct FlareGradientBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Inspector").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            FlareGradientBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// FILL and STROKE on the gallery's blue-to-white fill with a middle stop: each `.runFill` applied and logged.
private struct FlareGradientBudgetPage: View {
    // view-static: main-actor
    static var moves = 0
    @State private var fill = GradientRules.addingStop(GalleryGradientEditor.start, at: 0.5)?.fill ?? GalleryGradientEditor.start
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            FlareInspectorFill(paint: paint, reasonFor: { _ in nil }) { intent in
                guard case .inspector(.runFill(let gradient)) = intent else { return }
                if case .move = gradient { Self.moves += 1 }
                fill = GalleryGradientEditor.applied(gradient, to: fill)
                log.append("\(gradient.command.id) \(gradient)")
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }

    private var paint: PaintReadout {
        PaintReadout(fillHex: nil, fillIsGradient: true, strokeHex: "000000", strokeWidth: 1, cap: .butt, join: .miter,
                     gradient: FillSelection(fill: fill, box: GalleryGradientEditor.box))
    }
}
#endif
