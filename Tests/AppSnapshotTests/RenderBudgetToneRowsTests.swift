// RenderBudgetToneRowsTests.swift (tone-controls TC-4, quality rows "render: slider drag" and "render: Auto click"):
// what dragging a tone slider and clicking Auto cost in a real 1280 x 820 window. The window hosts ToneRows the way
// the gallery's `tone-rows` page does, its settings in a child page that applies each intent
// (GalleryToneRows.applied) and logs it, and counts the window's own bodies: 120 increments of
// `suite.tone.temperature` (the way VoiceOver and XCUI adjust it) send 120 `tone.set` intents and run at most 3
// window bodies; one Auto click sends one `tone.auto` and runs at most 2 (target 0 for both: only the page and the
// rows redraw). The p95 (packet: ≤ 8 ms) is printed, not gated: a step-time budget belongs in a
// Tests/perf-suites.txt test. Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteImaging
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetToneRowsTests {
        static let samples = 120

        private static func bodies() -> Int? {
            #if DEBUG
            return ToneRowsBudgetWindow.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func sliderDragInThreeBodies() async throws {
            let w = RenderBudgetWindow(ToneRowsBudgetWindow())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            _ = try #require(await w.element("suite.tone.temperature"), "the rows show no Temperature (suite.tone.temperature)")
            let sets = ToneRowsBudgetPage.sets
            let step = try await w.measure("tone-rows Temperature drag, \(Self.samples) steps", bodies: Self.bodies) {
                let found = try await w.adjust("suite.tone.temperature", steps: Self.samples)
                #expect(found, "Temperature can't be adjusted")
            }
            #expect(ToneRowsBudgetPage.sets - sets == Self.samples,
                    "\(Self.samples) Temperature steps sent \(ToneRowsBudgetPage.sets - sets) tone.set intents")
            expectBodies(step, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func autoInTwoBodies() async throws {
            let w = RenderBudgetWindow(ToneRowsBudgetWindow())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let auto = try #require(await w.element("suite.tone.auto"), "the rows show no Auto (suite.tone.auto)")
            let autos = ToneRowsBudgetPage.autos
            let step = try await w.measure("tone-rows Auto click", bodies: Self.bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: auto.midX, y: auto.midY)) }
            }
            #expect(ToneRowsBudgetPage.autos - autos == 1, "one Auto click sent \(ToneRowsBudgetPage.autos - autos) tone.auto")
            expectBodies(step, atMost: 2, target: 0)
        }
    }
}

/// The counted window: a header over the page, which owns the settings.
private struct ToneRowsBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Tone").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            ToneRowsBudgetPage()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's rows on neutral settings: each intent applied to the settings and logged.
private struct ToneRowsBudgetPage: View {
    // view-static: main-actor
    static var sets = 0
    // view-static: main-actor
    static var autos = 0
    @State private var settings = ToneSettings.neutral
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ToneRows(settings: settings, help: nil) { intent in
                if case .set = intent { Self.sets += 1 }
                if case .auto = intent { Self.autos += 1 }
                settings = GalleryToneRows.applied(intent, to: settings)
                log.append(GalleryToneRows.line(intent))
            }
            Text(log.last ?? "Nothing yet").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}
#endif
