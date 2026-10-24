// RenderBudgetLayerStyleTests.swift (layer-styles LS-4, quality row "render: 120-sample Distance scrub on the gallery
// page"): what scrubbing Drop Shadow's Distance costs in a real 1280 x 820 window. The window hosts LayerStylePanel
// the way the gallery's `layer-style` page does, its style in a child page that starts with Drop Shadow on, applies
// each Distance sample and logs each intent, and counts the window's own bodies: 120 increments of
// `suite.style.distance` (the way VoiceOver and XCUI adjust it) send 120 `style.set` intents and run at most 3 window
// bodies (target 0: only the page and the panel redraw). The p95 (packet: ≤ 8 ms) is printed, not gated: a step-time
// budget belongs in a Tests/perf-suites.txt test. Nested in BodyCountSuites: it reads a global body counter.
// macOS only.
#if canImport(AppKit)
import AppKit
import SuiteImaging
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLayerStyleTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func distanceScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(LayerStyleBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return LayerStyleBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            _ = try #require(await w.element("suite.style.distance"), "the panel shows no Distance row (suite.style.distance)")
            let sets = LayerStyleBudgetPage.distances
            let step = try await w.measure("layer-style Distance scrub, \(Self.samples) steps", bodies: bodies) {
                let found = try await w.adjust("suite.style.distance", steps: Self.samples)
                #expect(found, "Distance can't be adjusted")
            }
            #expect(LayerStyleBudgetPage.distances - sets == Self.samples,
                    "\(Self.samples) Distance steps sent \(LayerStyleBudgetPage.distances - sets) style.set intents")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the style.
private struct LayerStyleBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Layer Style").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            LayerStyleBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's panel half on a style with Drop Shadow on: each Distance sample applied, each intent logged.
private struct LayerStyleBudgetPage: View {
    // view-static: main-actor
    static var distances = 0
    @State private var style = LayerStyle(effects: [StyleRules.defaults(.dropShadow)], fillOpacity: 1)
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            LayerStylePanel(style: style, selected: .dropShadow, help: nil) { intent in
                if case .set(.dropShadow, .object(let patch), _) = intent, case .number(let d)? = patch["distance"] {
                    Self.distances += 1
                    style = Self.moved(style, distance: d)
                }
                log.append(GalleryLayerStyle.line(intent))
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.min + SuiteSize.inspectorWidth.max)
        .background(SuiteColor.panel)
    }

    /// `style` with its drop shadow's distance at `distance` (StyleRules.setting is a stub until LS-5).
    private static func moved(_ style: LayerStyle, distance: Double) -> LayerStyle {
        var next = style
        for i in next.effects.indices where next.effects[i].kind == .dropShadow {
            if case .shadow(var s) = next.effects[i].parameters { s.distance = distance; next.effects[i].parameters = .shadow(s) }
        }
        return next
    }
}
#endif
