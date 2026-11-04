// RenderBudgetHomeSearchTests.swift: QB-S4 in the window (home packet, quality rows; Tests/render-budgets.md):
// the home's Recents on 200 documents, typed into and erased again one keystroke per real 1/120 s, each
// step `HomeModel.search` then the layout and display it forces. A keystroke runs at most one grid body
// and its p95 stays within one frame (render-contract rule 3: 8 ms, 16 ms hard). `timing` waits on
// Tests/perf-suites.txt. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SwiftUI
import Testing

@testable import AfterGlowApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHomeSearchTests {
        /// Type "Doc 1" and erase it, six times: 60 keystrokes, each a different match count from the last.
        static let keystrokes: [String] = {
            let typed = (1...5).map { String("Doc 1".prefix($0)) }
            return Array(repeating: typed + typed.reversed().dropFirst() + [""], count: 6).flatMap { $0 }
        }()

        @Test(.timeLimit(.minutes(2))) func keystrokeRunsOneGridBody() async throws {
            let (typing, shown) = try await Self.run()
            expectBodies(typing, atMost: Self.keystrokes.count + 2, target: Self.keystrokes.count)
            #expect(shown == 200, "erasing the query left \(shown) of 200 cards")
        }

        @Test(.disabled("report-only: enable once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(2)))
        func timing() async throws {
            let (typing, _) = try await Self.run()
            expectP95(typing, atMost: 16, target: 8)
        }

        static func run() async throws -> (typing: RenderStep, shown: Int) {
            let refs = HomePreviewFixture.refs(200)
            let (model, services) = await HomePreviewFixture.model(refs, thumbnails: AskingThumbnails(seeded: refs))
            #expect(model.state.cards.count == 200)
            let w = RenderBudgetWindow(HomePreviewFixture.grid(model, services, previews: HomeGrid.previews()),
                                       size: CGSize(width: 900, height: 600))
            defer { w.close() }
            try await w.settle(400)
            try await w.settle(untilStable: HomePreviewFixture.bodies, turns: 8)
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            var counts: Set<Int> = []
            let typing = try await w.measure("home search, 200 recents", bodies: HomePreviewFixture.bodies) {
                try await w.ticks(Self.keystrokes.count) { i in
                    model.search(Self.keystrokes[i - 1], now: now)
                    counts.insert(model.state.cards.count)
                }
            }
            #expect(counts.count >= 2, "the keystrokes never changed what the grid shows: \(counts)")
            return (typing, model.state.cards.count)
        }
    }
}
#endif
