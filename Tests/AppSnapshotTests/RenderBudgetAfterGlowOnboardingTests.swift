// RenderBudgetAfterGlowOnboardingTests.swift: the welcome window's render
// budget (Tests/render-budgets.md) on OnboardingWindow.bodyRuns, through the
// harness (RenderBudgetHarness.swift), on an OnboardingModel over the fakes.
// It clicks Continue (page 1 to 2), clicks the Photos focus chip, goes on to
// the start page and moves the pointer 120 samples across the first starter
// row. `bodies` gates the window-body counts; `timing`
// (Tests/perf-suites.txt, report-only) judges the step times. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import AfterGlowApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetAfterGlowOnboardingTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (next, chip, hover) = try await Self.run()
            // A page change is one model change: the window's body once, twice with the button's own update.
            expectBodies(next, atMost: 1, target: 1)  // dev: 1
            // A focus chip changes the focus and the starters; the page reads them, the window at most once.
            expectBodies(chip, atMost: 0, target: 0)  // dev: 0
            // Hovering is presentation only. Target: 0.
            expectBodies(hover, atMost: 0, target: 0)  // dev: 0
        }

        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let (next, chip, hover) = try await Self.run()
            // Targets: a click fits one 60 Hz frame; a pointer move one 120 Hz frame.
            expectP95(next, atMost: 35, target: 16)  // dev: 14 ms (31 ms cold)
            expectP95(chip, atMost: 30, target: 16)  // dev: 9.5 ms (24 ms cold)
            expectP95(hover, atMost: 1, target: 8.3)  // dev: 0.09 ms
        }

        static func run() async throws -> (next: RenderStep, chip: RenderStep, hover: RenderStep) {
            let model = OnboardingModel(services: .fake(), samplesFolder: "/fixture/Samples",
                                        documents: "/fixture/Documents", present: { _ in true },
                                        copy: { _, _ throws(SuiteError) in }, makeID: { "ob1" })
            await model.load()
            let size = CGSize(width: OnboardingLayout.width, height: OnboardingLayout.height)
            let w = RenderBudgetWindow(OnboardingWindow(model: model), size: size)
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return OnboardingWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)

            let go = try #require(await w.element(OnboardingControls.continue), "no Continue")
            let next = try await w.measure("onboarding Continue click", bodies: bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: go.midX, y: go.midY)) }
            }
            #expect(model.pageIndex == 1, "Continue didn't turn the page: \(next)")

            try await w.settle(untilStable: bodies)
            let photos = try #require(await w.element(OnboardingControls.focus(.photos)), "no Photos chip")
            let chip = try await w.measure("onboarding focus chip click", bodies: bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: photos.midX, y: photos.midY)) }
            }
            #expect(model.focus == .photos, "the chip chose nothing: \(chip)")

            let goOn = try #require(await w.element(OnboardingControls.continue), "no Continue on the focus page")
            w.click(at: CGPoint(x: goOn.midX, y: goOn.midY))
            try await w.settle(untilStable: bodies)
            #expect(model.isLastPage, "Continue didn't reach the start page")
            let first = try #require(model.starters.first, "no starters")
            let page = try #require(await w.element(OnboardingControls.page), "no page")
            let sample = try #require(await w.element(OnboardingControls.sample(first.tile.app)), "no Open sample")
            let hover = try await w.measure("onboarding starter row hover, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in
                    let x = page.minX + (sample.maxX - page.minX) * Double(i) / 120
                    w.send(.mouseMoved, at: CGPoint(x: x, y: sample.midY))
                }
            }
            return (next, chip, hover)
        }
    }
}
#endif
