// RenderBudgetFileDropTests.swift (file-flow SF-4): what a file drag over a window costs (Tests/render-budgets.md),
// through the harness (RenderBudgetHarness.swift). A real drag session can't run in a test process, so the
// drop modifier's hover is driven the way its delegate drives it: files enter and are planned ("Open in
// Halo"), 120 pointer moves cross the window, the files leave; then a refused file is dropped and its mark
// lingers. The window's content must not render again for the mark: it is an overlay of its own. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFileDropTests {
        @Test(.timeLimit(.minutes(2))) func dragHoverInTwoBodies() async throws {
            let hover = SuiteDropHover()
            let w = RenderBudgetWindow(DropStage(hover: hover))
            defer { w.close() }
            try await w.settle(untilStable: { DropStage.bodyRuns })
            let halo: [DropAction] = [.handOff(path: "/tmp/Intro.halo", app: "halo")]
            let step = try await w.measure("file drag hover over the home: mark, 120 moves, leave", bodies: { DropStage.bodyRuns }) {
                try await w.ticks(1) { _ in hover.planned(halo, for: hover.begin()) }
                #expect(await w.element(SuiteFileControlID.dropMark) != nil, "the hover shows no mark")
                #expect(w.label(SuiteFileControlID.dropMark) == "Open in Halo", "the hover shows no Open in Halo mark")
                try await w.ticks(120) { i in w.send(.mouseMoved, at: CGPoint(x: 200 + 6 * i, y: 400)) }
                try await w.ticks(1) { _ in hover.exit() }
            }
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the mark stayed after the files left")
            // The mark is an overlay: the window's content renders at most for the mark's arrival and exit. Target: 0.
            expectBodies(step, atMost: 2, target: 0)

            let xyz: [DropAction] = [.refuse(path: "/tmp/notes.xyz", reason: "AfterGlow can't open .xyz files.")]
            hover.dropped(xyz, linger: .milliseconds(400))
            #expect(await w.element(SuiteFileControlID.dropMark) != nil, "the drop shows no mark")
            #expect(w.label(SuiteFileControlID.dropMark) == "AfterGlow can't open .xyz files.",
                    "the refusal isn't readable after the drop")
            try await w.settle(800)
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the refusal stayed past its linger")
        }

        @Test func aLatePlanForAnEndedHoverIsIgnored() {
            let hover = SuiteDropHover()
            let first = hover.begin()
            hover.exit()
            hover.planned([.open(path: "/tmp/Poster.design")], for: first)
            #expect(hover.actions.isEmpty, "a plan that came after the files left showed a mark")
            let second = hover.begin()
            hover.planned([.open(path: "/tmp/Poster.design")], for: second)
            #expect(hover.actions.count == 1)
        }
    }
}

/// A home-sized window with the drop modifier on it, counting its own bodies.
private struct DropStage: View, BodyCounted {
    @Environment(\.bodyTally) private var bodyTally
    let hover: SuiteDropHover

    var body: some View {
        bodyTally.ran(Self.self)
        return Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(SuiteFileDropModifier(app: .launcher, documentName: nil, plan: { _ in [] }, perform: { _ in },
                                            hover: hover))
    }
}
#endif
