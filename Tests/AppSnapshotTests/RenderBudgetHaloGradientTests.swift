// RenderBudgetHaloGradientTests.swift (gradient-fill HG-3, Quality row "render: stop drag"): what dragging a gradient
// stop in Halo's FILL section costs in a real 1280 x 820 window. The window hosts HaloFillInspector on a three-stop
// linear fill, the fill in a child page that applies each `runFill` intent through the kernel's rules
// (GalleryGradientEditor.applied) and logs it, since HaloProject.runFill is a stub until HG-7, and counts the window's
// own bodies: 40 increments of the middle stop (`suite.gradient.stop.1`, the way VoiceOver and XCUI adjust it) send
// 40 `move` intents and run at most 3 window bodies (target 0: only the page and the section redraw). The p95 is
// printed, not gated. Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloGradientTests {
        /// 1% each: the middle stop goes from 50% to 90%, never past the last stop.
        static let samples = 40

        @Test(.timeLimit(.minutes(2))) func stopDragInThreeBodies() async throws {
            let w = RenderBudgetWindow(HaloGradientBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return HaloGradientBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(500)
            _ = try #require(await w.element("suite.gradient.stop.1"), "FILL shows no middle stop (suite.gradient.stop.1)")
            let moves = HaloGradientBudgetPage.moves
            let step = try await w.measure("halo FILL stop drag, \(Self.samples) steps", bodies: bodies) {
                let found = try await w.adjust("suite.gradient.stop.1", steps: Self.samples)
                #expect(found, "the middle stop can't be adjusted")
            }
            #expect(HaloGradientBudgetPage.moves - moves == Self.samples,
                    "\(Self.samples) stop steps sent \(HaloGradientBudgetPage.moves - moves) move intents")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the fill.
private struct HaloGradientBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Inspector").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            HaloGradientBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// FILL on the gallery's blue-to-white fill with a middle stop: each `runFill` intent applied and logged.
private struct HaloGradientBudgetPage: View {
    // view-static: main-actor
    static var moves = 0
    @State private var fill = GradientRules.addingStop(GalleryGradientEditor.start, at: 0.5)?.fill ?? GalleryGradientEditor.start
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HaloFillInspector(
                selection: FillSelection(fill: fill, box: GalleryGradientEditor.box), help: nil, color: nil,
                colorHelp: nil,
                runFill: { intent in
                    if case .move = intent { Self.moves += 1 }
                    fill = GalleryGradientEditor.applied(intent, to: fill)
                    log.append("\(intent.command.id) \(intent)")
                })
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}
#endif
