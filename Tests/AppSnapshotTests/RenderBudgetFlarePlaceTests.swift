// RenderBudgetFlarePlaceTests.swift (svg-place PF-4, quality row "place: a 2,000-path SVG on a live stage"): one
// place of a 2,000-path SVG, sent through FlareWindow's debug-only `placeProbe` as the menu and drop send it, runs
// the window's body at most 3 times (target 1). The time is printed, not gated (perf-suites only). Until PF-5 the
// place refuses and this covers the refusal's status line. In BodyCountSuites: a global counter. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

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
            var open = FlareWorkspace(services: .built)
            open.newDocument()
            let w = RenderBudgetWindow(FlareWindow(model: open))
            defer { w.close() }
            try await w.settle(500)
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            #if DEBUG
            let place = try #require(FlareWindow.placeProbe, "the window published no place probe")
            let file = (name: "many-paths.svg", data: Self.manyPaths)
            let step = try await w.measure("flare place 2,000-path SVG", bodies: bodies) {
                w.timed { place([file]) }
                try await w.settle(500)
            }
            print("RENDER-BUDGET flare place 2000-path SVG step \(String(format: "%.2f", step.p95)) ms (print-only)")
            let status = FlareWindow.shownModel?.placeStatus
            #expect(status?.isEmpty == false, "the place left nothing in the status line")
            expectBodies(step, atMost: 3, target: 1)
            #endif
        }
    }
}
#endif
