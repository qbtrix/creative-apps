// RenderBudgetFlarePlaceTests.swift (svg-place quality row "place: a 2,000-path SVG on a live stage"): one place
// of a 2,000-path SVG, sent through FlareWindow's debug-only `placeProbe` as the menu and drop send it, on a new
// document with the stage live. `bodies` gates the window body at most 3 runs (target 1) and the status line's
// report; `timing` places it 20 times, each on a fresh window, and gates the steps' p95 at 200 ms (svg-place.md's
// budget), since one sample is the median's luck, not a p95. It is disabled until Tests/perf-suites.txt lists it,
// so a loaded CI Mac can't redden the merge gate.
// In BodyCountSuites: a global counter. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import Foundation
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlarePlaceTests {
        /// 2,000 small squares in a 400 × 200 drawing, each its own path.
        static let manyPaths: Data = {
            let paths = (0..<2_000).map { i in
                let x = (i % 50) * 8, y = (i / 50) * 5
                return "<path fill=\"#1E88E5\" d=\"M\(x) \(y) h6 v4 h-6 Z\"/>"
            }
            return Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"400\" height=\"200\">"
                + paths.joined() + "</svg>").utf8)
        }()

        @Test(.timeLimit(.minutes(2))) func placeInThreeBodies() async throws {
            guard let (step, status) = try await Self.run() else { return }
            #expect(status?.hasPrefix("Placed many-paths.svg: ") == true, "the place didn't report: \(String(describing: status))")
            expectBodies(step, atMost: 3, target: 1)
        }

        @Test(.timeLimit(.minutes(5)), .disabled("waits on its Tests/perf-suites.txt line"))
        func timing() async throws {
            var steps: [Double] = []
            for _ in 0..<Self.timedRuns {
                guard let (step, _) = try await Self.run() else { return }
                steps.append(step.p95)
            }
            let p95 = SuiteFrameProbe.nearestRank(steps.sorted(), 0.95) ?? .infinity
            print("RENDER-BUDGET flare place 2000-path SVG over \(steps.count) runs: p95 \(String(format: "%.2f", p95)) ms")
            #expect(p95 <= 200, "place p95 \(p95) ms over \(steps.count) runs (budget 200 ms, target 100 ms): \(steps)")
        }

        /// How many places `timing` gates the p95 over.
        static let timedRuns = 20

        /// The place step and the status line after it; nil in a release build, which has no place probe.
        static func run() async throws -> (RenderStep, String?)? {
            var open = FlareWorkspace(services: .built)
            open.newDocument()
            let w = RenderBudgetWindow(FlareWindow(model: open))
            defer { w.close() }
            try await w.settle(500)
            #if DEBUG
            let place = try #require(FlareWindow.placeProbe, "the window published no place probe")
            let file = (name: "many-paths.svg", data: Self.manyPaths)
            let step = try await w.measure("flare place 2,000-path SVG", bodies: { FlareWindow.bodyRuns }) {
                w.timed { place([file]) }
                try await w.settle(500)
            }
            print("RENDER-BUDGET flare place 2000-path SVG step \(String(format: "%.2f", step.p95)) ms")
            return (step, FlareWindow.shownModel?.placeStatus)
            #else
            return nil
            #endif
        }
    }
}
#endif
