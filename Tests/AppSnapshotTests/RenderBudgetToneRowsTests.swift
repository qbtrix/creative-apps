// RenderBudgetToneRowsTests.swift (tone-controls TC-4): ToneRows in a real window, hosted like the gallery page.
// 120 Temperature steps send one `tone.set` per step until the top of the range (100; a step there changes
// nothing and sends nothing) in at most 3 window bodies; one Auto click one `tone.auto` in at most 2
// (target 0: only the page redraws). The p95 (packet: ≤ 8 ms) is printed, not gated. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteImaging
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetToneRowsTests {
        static let samples = 120
        /// The steps that change Temperature: from neutral up to the top of its range, then clamped.
        static let moving = min(samples, Int((ToneSlider.temperature.range.upperBound - ToneSlider.temperature.neutral)
            / ToneSlider.temperature.step))

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
            #expect(ToneRowsBudgetPage.sets - sets == Self.moving,
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

/// The counted window around the page, which owns the settings.
private struct ToneRowsBudgetWindow: View {
    #if DEBUG
    // view-static: main-actor
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        ToneRowsBudgetPage()
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
    @State private var last = "Nothing yet"

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ToneRows(settings: settings, help: nil) { intent in
                if case .set = intent { Self.sets += 1 } else if case .auto = intent { Self.autos += 1 }
                settings = GalleryToneRows.applied(intent, to: settings)
                last = GalleryToneRows.line(intent)
            }
            Text(last).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
        }
        .frame(width: SuiteSize.inspectorWidth.ideal)
        .background(SuiteColor.panel)
    }
}
#endif
