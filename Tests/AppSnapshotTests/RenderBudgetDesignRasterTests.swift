// RenderBudgetDesignRasterTests.swift: the write's render budget (design-export DE-8, the
// "render: the write (DE-w)" row and QD-S12). The real Design window is open on `cards`
// through the harness (RenderBudgetHarness.swift); once its body count is steady, the 2x PNG
// of the Desktop frame (2880 × 2048 px) is planned by the Model (exportRaster) and drawn and
// encoded by DesignRasterizer. The window body runs 0 times during the write: the raster is
// drawn off the window and reads no window state. `write` gates the body count; `writeTiming`
// gates the wall time on its 1 s budget, failing over it. `writeTiming` is on the perf list
// (Tests/perf-suites.txt). `nodeCost` (OD-17) is recorded, not gated: per node kind
// (`DesignFixtures.animated(_:kinds:)`) it rasters the tree sampled at 31 frames through
// DesignArtwork at 2x, the canvas painter off the window, and prints p50 and p95 per node, the
// kind's compositor trigger (the node count whose p95 passes 8.3 ms, extrapolated linearly) and
// the 1-minute load; its only checks are the node counts. Measure it on a release build. Nested in
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
            let (step, png) = try await Self.run()
            #expect((png?.count ?? 0) > 0, "the 2x PNG was not written")
            expectBodies(step, atMost: 0, target: 0)
        }

        /// QD-S12: 2x PNG of 1440 × 1024 written in at most 1 s wall; fails over it.
        @Test(.timeLimit(.minutes(2))) func writeTiming() async throws {
            let (step, _) = try await Self.run()
            print("RENDER-BUDGET design write a 2x PNG: \(String(format: "%.1f", step.p95)) ms (budget 1000 ms)")
            #expect(step.p95 <= 1000, "\(step) (budget 1000 ms)")
        }

        /// OD-17: the painter's raster cost per node kind, printed, not gated (the rows in Tests/render-budgets.md).
        @Test(.timeLimit(.minutes(5))) func nodeCost() throws {
            for kinds in DesignFixtures.AnimatedKinds.allCases {
                let count = kinds == .realUI ? 200 : 500
                let page = try #require(DesignFixtures.animated(count, kinds: kinds).selectedPage)
                func nodes(_ list: [DesignNode]) -> Int { list.reduce(list.count) { $0 + nodes($1.children) } }
                let total = nodes(page.nodes)
                #expect(total == (kinds == .realUI ? 197 : 501), "\(kinds)")
                func raster(_ frame: Double) {
                    let renderer = ImageRenderer(content: DesignArtwork(painted: page.sampled(at: frame).painted, zoom: 1)
                        .frame(width: page.frameWidth, height: page.frameHeight))
                    renderer.scale = 2
                    _ = renderer.cgImage
                }
                raster(0)  // warm-up: the first text render loads its fonts
                var times: [Double] = []
                for frame in stride(from: 0, through: 120, by: 4) {
                    let clock = ContinuousClock(), began = clock.now
                    raster(Double(frame))
                    times.append(Double((clock.now - began) / .microseconds(1)) / 1000)
                }
                let sorted = times.sorted(), p50 = sorted[sorted.count / 2], p95 = sorted[Int(Double(sorted.count) * 0.95)]
                var load = [0.0, 0, 0]
                getloadavg(&load, 3)
                print(String(format: "RENDER-BUDGET design raster %@ (%d nodes) at 2x, %d frames: p50 %.2f p95 %.2f ms | per node p50 %.2f p95 %.2f us | trigger %d nodes | load %.0f",
                             kinds.rawValue, total, sorted.count, p50, p95, p50 * 1000 / Double(total), p95 * 1000 / Double(total),
                             Int(8.3 * Double(total) / p95), load[0]))
            }
        }

        static func run() async throws -> (step: RenderStep, png: Data?) {
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
            return (step, png)
        }
    }
}
#endif
