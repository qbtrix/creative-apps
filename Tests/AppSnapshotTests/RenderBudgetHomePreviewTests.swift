// RenderBudgetHomePreviewTests.swift: the home's Recents with previews (shared-thumbnails ST-4,
// Tests/render-budgets.md): 40 cards on FakeThumbnails (every third without a preview), once every
// answer is in and the grid body is still, scrolled 120 steps of 12 points. A scroll asks for nothing
// and runs at most 3 grid bodies. `timing` waits on Tests/perf-suites.txt. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import AfterGlowApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHomePreviewTests {
        @Test(.timeLimit(.minutes(2))) func scrollRecentsInThreeBodies() async throws {
            let (scroll, asked) = try await Self.run()
            expectBodies(scroll, atMost: 3, target: 0)
            #expect(asked == 40, "a scroll asked for previews again: \(asked) asks for 40 cards")
        }

        @Test(.disabled("report-only: enable once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(2)))
        func timing() async throws {
            let (scroll, _) = try await Self.run()
            expectP95(scroll, atMost: 8, target: 8)
        }

        static func run() async throws -> (scroll: RenderStep, asked: Int) {
            let refs = HomePreviewFixture.refs(40)
            let thumbnails = AskingThumbnails(seeded: refs.enumerated().filter { $0.offset % 3 != 2 }.map(\.element))
            let (model, services) = await HomePreviewFixture.model(refs, thumbnails: thumbnails)
            #expect(model.state.cards.count == 40)
            let w = RenderBudgetWindow(HomePreviewFixture.grid(model, services, previews: HomeGrid.previews()),
                                       size: CGSize(width: 900, height: 600))
            defer { w.close() }
            try await w.settle(400)
            try await w.settle(untilStable: HomePreviewFixture.bodies, turns: 8)
            let first = try #require(w.identifiers().first { $0.hasPrefix("afterglow.home.card.") }, "no Recent cards")
            let cell = try #require(await w.element(first))
            let grid = try #require(w.scrollView(at: CGPoint(x: cell.midX, y: cell.midY)), "no Recents scroll view")
            var scrolled: (before: CGFloat, after: CGFloat) = (0, 0)
            let scroll = try await w.measure("home recents scroll, 40 cards with previews", bodies: HomePreviewFixture.bodies) {
                scrolled = try await w.scroll(grid, by: 12)
            }
            #expect(scrolled.after > scrolled.before, "the Recents never scrolled: \(scrolled)")
            return (scroll, await thumbnails.asked.count)
        }
    }
}
#endif
