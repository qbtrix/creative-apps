// RenderBudgetLayerStyleTests.swift (layer-styles LS-4, quality row "render: 120-sample Distance scrub on the gallery
// page"): what scrubbing a drop shadow's Distance costs in a real 1280 x 820 window. The window hosts LayerStylePanel
// the way the gallery's `layer-style` page does, its style in a child page that applies each intent
// (GalleryLayerStyle.applied) and logs it, and counts the window's own bodies: 120 increments of
// `suite.style.distance` send 120 `style.set`s, each in at most 3 window bodies (target 0: only the page and the
// panel redraw). Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteImaging
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLayerStyleTests {
        static let samples = 120

        static func bodies() -> Int? {
            #if DEBUG
            return LayerStyleBudgetWindow.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func distanceScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(LayerStyleBudgetWindow())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            _ = try #require(await w.element("suite.style.distance"), "the panel shows no Distance row (suite.style.distance)")
            let before = LayerStyleBudgetPage.sets
            let step = try await w.measure("layer-style Distance scrub, \(Self.samples) steps", bodies: Self.bodies) {
                let found = try await w.adjust("suite.style.distance", steps: Self.samples)
                #expect(found, "Distance can't be adjusted")
            }
            #expect(LayerStyleBudgetPage.sets - before == Self.samples,
                    "\(Self.samples) Distance steps sent \(LayerStyleBudgetPage.sets - before) style.set intents")
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

/// The gallery page's panel half on a drop shadow: each intent applied to the style and logged.
private struct LayerStyleBudgetPage: View {
    // view-static: main-actor
    static var sets = 0
    @State private var style = GalleryLayerStyle.applied(.toggle(.dropShadow, true), to: GalleryLayerStyle.start)
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            LayerStylePanel(style: style, selected: .dropShadow, help: nil) { intent in
                if case .set = intent { Self.sets += 1 }
                style = GalleryLayerStyle.applied(intent, to: style)
                log.append(GalleryLayerStyle.line(intent))
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(minWidth: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}
#endif
