// RenderBudgetGradientEditorTests.swift (gradient-fill GF-4, quality rows "render: 120-sample stop drag on the
// gallery page" and "render: 120-sample angle scrub"): what dragging a stop and scrubbing the angle cost in a real
// 1280 x 820 window. The window hosts GradientEditor the way the gallery's `gradient-editor` page does, its fill in a
// child page that applies each intent (GalleryGradientEditor.applied) and logs it, and counts the window's own
// bodies: a 120-sample drag of `suite.gradient.stop.1` sends `fill.stop-move`s under one drag token, and 120
// increments of `suite.gradient.angle` send 120 `fill.angle`s, each in at most 3 window bodies (target 0: only the
// page and the editor redraw). The p95 (packet: ≤ 8 ms) is printed, not gated: a step-time budget belongs in a
// Tests/perf-suites.txt test. Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetGradientEditorTests {
        static let samples = 120

        static func bodies() -> Int? {
            #if DEBUG
            return GradientEditorBudgetWindow.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func stopDragInThreeBodies() async throws {
            let w = RenderBudgetWindow(GradientEditorBudgetWindow().allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let stop = try #require(await w.element("suite.gradient.stop.1"), "the editor shows no middle stop (suite.gradient.stop.1)")
            let bar = try #require(await w.element("suite.gradient.bar"), "the editor shows no stop bar (suite.gradient.bar)")
            let before = GradientEditorBudgetPage.moves
            let step = try await w.measure("gradient-editor stop drag, \(Self.samples) samples", bodies: Self.bodies) {
                try await w.drag(from: CGPoint(x: stop.midX, y: stop.midY), by: CGVector(dx: -bar.width * 0.3, dy: 0), samples: Self.samples)
            }
            #expect(GradientEditorBudgetPage.moves - before > 0, "the stop drag sent no fill.stop-move")
            #expect(GradientEditorBudgetPage.tokens.count == 1, "one stop drag sent \(GradientEditorBudgetPage.tokens.count) drag tokens")
            expectBodies(step, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func angleScrubInThreeBodies() async throws {
            let w = RenderBudgetWindow(GradientEditorBudgetWindow())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            _ = try #require(await w.element("suite.gradient.angle"), "the editor shows no Angle row (suite.gradient.angle)")
            let before = GradientEditorBudgetPage.angles
            let step = try await w.measure("gradient-editor Angle scrub, \(Self.samples) steps", bodies: Self.bodies) {
                let found = try await w.adjust("suite.gradient.angle", steps: Self.samples)
                #expect(found, "Angle can't be adjusted")
            }
            #expect(GradientEditorBudgetPage.angles - before == Self.samples,
                    "\(Self.samples) Angle steps sent \(GradientEditorBudgetPage.angles - before) fill.angle intents")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the fill.
private struct GradientEditorBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Fill").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            GradientEditorBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's editor half on a three-stop linear fill: each intent applied to the fill and logged.
private struct GradientEditorBudgetPage: View {
    // view-static: main-actor
    static var moves = 0, angles = 0, tokens: Set<String> = []
    @State private var fill = GalleryGradientEditor.applied(.add(offset: 0.5), to: GalleryGradientEditor.start)
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            InspectorSection("Fill") {
                GradientEditor(fill: fill, box: GalleryGradientEditor.box) { intent in
                    switch intent {
                    case .move(_, _, let drag): Self.moves += 1; Self.tokens.insert(drag)
                    case .angle: Self.angles += 1
                    default: break
                    }
                    fill = GalleryGradientEditor.applied(intent, to: fill)
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
