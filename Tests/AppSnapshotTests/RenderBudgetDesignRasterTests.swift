// RenderBudgetDesignRasterTests.swift: the write's render budget (design-export DE-8, the
// "render: the write (DE-w)" row and QD-S12). The real Design window is open on `cards`
// through the harness (RenderBudgetHarness.swift); once its body count is steady, the 2x PNG
// of the Desktop frame (2880 × 2048 px) is planned by the Model (exportRaster) and drawn and
// encoded by DesignRasterizer. The window body runs 0 times during the write: the raster is
// drawn off the window and reads no window state. The wall time is reported against its 1 s budget; this test gates only at 3 times
// that, as the Perf step flags, since timing belongs in Tests/perf-suites.txt. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignRasterTests {
        @Test(.timeLimit(.minutes(2))) func write() async throws {
            let cards = DesignFixtures.cards
            let desktop = try #require(try cards.exportPlan(DesignExportOptions(scale: 2), existing: []).first)
            #expect(desktop.pixelWidth == 2880 && desktop.pixelHeight == 2048)
            let w = RenderBudgetWindow(DesignWindow(seed: cards))
            defer { w.close() }
            try await w.settle(500)
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            var png: Data?
            let step = try await w.measure("design write a 2x PNG", bodies: bodies) {
                w.timed { png = try? DesignRasterizer.png(cards.exportRaster(desktop)) }
            }
            #expect((png?.count ?? 0) > 0, "the 2x PNG was not written")
            expectBodies(step, atMost: 0, target: 0)
            // QD-S12: 2x PNG of 1440 × 1024 written in at most 1 s wall; reported, gated at 3x.
            print("RENDER-BUDGET design write a 2x PNG: \(String(format: "%.1f", step.p95)) ms (budget 1000 ms)")
            #expect(step.p95 <= 3000, "\(step) (budget 1000 ms)")
        }
    }
}
#endif
