// RenderBudgetShapeToolsTests.swift (shape-tools SH-4, quality row "render:
// 120-sample Points scrub"): what scrubbing Star's Points costs in a real 1280
// x 820 window. The window hosts ShapeToolOptions the way the gallery's
// `shape-tools` page does, its spec in a child page that applies each intent
// and logs it, and counts the window's own bodies: 120 increments of
// `suite.shape.points` (the way VoiceOver and XCUI adjust it) run at most 3
// window bodies (target 0: only the page and the row redraw). The star drag
// row waits on SH-7: the page's canvas gesture ignores the harness's
// window-activation presses until it opts in. Nested in BodyCountSuites: it
// reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetShapeToolsTests {
        @Test(.timeLimit(.minutes(2))) func pointsScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(ShapeToolsBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return ShapeToolsBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            _ = try #require(await w.element("suite.shape.points"), "Star shows no Points row (suite.shape.points)")
            let step = try await w.measure("shape-tools Points scrub, 120 steps", bodies: bodies) {
                let found = try await w.adjust("suite.shape.points", steps: 120)
                #expect(found, "Points can't be adjusted")
            }
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the spec.
private struct ShapeToolsBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Shape tool").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            ShapeToolsBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's options half on Star: each intent applied to the spec and logged.
private struct ShapeToolsBudgetPage: View {
    @State private var spec = ShapeSpec.defaults(.star)
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ShapeToolOptions(spec: spec, help: ShapeRules.help(spec)) { intent in
                spec = intent.applied(to: spec)
                log.append("\(intent.command.id) \(intent)")
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
    }
}
#endif
