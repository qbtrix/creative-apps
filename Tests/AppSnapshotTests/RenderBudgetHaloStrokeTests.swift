// RenderBudgetHaloStrokeTests.swift (stroke-style HK-4, Quality row "render: trim scrub"): what scrubbing Trim End
// in Halo's STROKE section costs in a real 1280 x 820 window. The window hosts HaloStrokeInspector on a 2 pt stroke
// trimmed to nothing, with its three trim keys, the stroke in a child page that applies each `runStroke` intent
// through the kernel's rules (GalleryStrokeEditor.applied) and logs it, since HaloProject.runStroke is a stub until
// HK-6, and counts the window's own bodies: 120 increments of `suite.stroke.trim-end` (the way VoiceOver and XCUI
// adjust it) send trim intents until the end reaches 100% and run at most 3 window bodies (target 0: only the page
// and the section redraw). The viewer is not in the window: Halo draws no trim until HK-5/HK-6, so the live viewer's
// share waits on them. The p95 (packet: ≤ 16 ms) is printed, not gated. Nested in BodyCountSuites: it reads a
// global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import FlareCore
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloStrokeTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func trimScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(HaloStrokeBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return HaloStrokeBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            _ = try #require(await w.element("suite.stroke.trim-end"), "STROKE shows no Trim End row (suite.stroke.trim-end)")
            let trims = HaloStrokeBudgetPage.trims
            let step = try await w.measure("halo STROKE Trim End scrub, \(Self.samples) steps", bodies: bodies) {
                let found = try await w.adjust("suite.stroke.trim-end", steps: Self.samples)
                #expect(found, "Trim End can't be adjusted")
            }
            let sent = HaloStrokeBudgetPage.trims - trims
            #expect(sent > 0 && sent <= Self.samples, "\(Self.samples) Trim End steps sent \(sent) trim intents")
            #expect((HaloStrokeBudgetPage.stroke?.trim?.end ?? 0) > 0, "the scrub moved Trim End")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the stroke.
private struct HaloStrokeBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Inspector").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            HaloStrokeBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// STROKE on a 2 pt stroke drawing nothing (Trim End 0%), its trim keys animated: each intent applied and logged.
private struct HaloStrokeBudgetPage: View {
    // view-static: main-actor
    static var trims = 0
    // view-static: main-actor
    static var stroke: VectorStroke?
    @State private var stroke: VectorStroke? = VectorStroke(width: 2, trim: StrokeTrim(start: 0, end: 0))
    @State private var log: [String] = []

    private static let keys = [
        HaloTrimKey(raw: "trimStart", title: "Trim Start", keyState: .notAnimated, help: nil),
        HaloTrimKey(raw: "trimEnd", title: "Trim End", keyState: .animated, help: nil),
        HaloTrimKey(raw: "trimOffset", title: "Trim Offset", keyState: .notAnimated, help: nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HaloStrokeInspector(
                stroke: stroke, help: nil, trimKeys: Self.keys,
                runStroke: { intent in
                    if case .trim = intent { Self.trims += 1 }
                    stroke = GalleryStrokeEditor.applied(intent, to: stroke)
                    Self.stroke = stroke
                    log.append("\(intent.command.id) \(intent)")
                })
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}
#endif
