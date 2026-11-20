// DesignInspectorTypingTests.swift: an inspector edit made after a press whose mouse-up never reached
// SwiftUI still lands as its own undo step, in Design's real window. That press is a click into a text
// field (a gradient stop's hex, a scrub's typing field): the field tracks the mouse in its own loop, so
// the rows around it see the press and never its release. A row that took the press alone as "a drag is
// under way" then previewed the typed value on the live box and never landed it (journey
// DesignGradientJourneyTests, "the hex field made no colour step"). A test process can't click a text
// field (its mouse loop ends swift-testing's main queue), so the press here is a mouse-down with no
// mouse-up on a bar, and the edit an accessibility step, which like a typed value has no pointer in it.
// `cards` with A on DesignGradientSeed's linear gradient, in a window tall enough for the Fill rows. It
// reads DesignWindow.lastWorkspace, a static, so it nests in BodyCountSuites. macOS debug builds only.
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignInspectorTypingTests {
        @Test(.timeLimit(.minutes(2))) func aGradientEditAfterAnUnendedPressIsOneStep() async throws {
            let after = try await Self.stepAfterPress("suite.gradient.location")
            #expect(after.undoActionName == "Undo Move Gradient Stop", "Undo reads \(after.undoActionName)")
        }

        @Test(.timeLimit(.minutes(2))) func aFrameEditAfterAnUnendedPressIsOneStep() async throws {
            let after = try await Self.stepAfterPress(DesignControlID.frameField(.x))
            #expect(after.selectedNode?.frame.x == 101, "X reads \(String(describing: after.selectedNode?.frame.x))")
        }

        /// Presses the bar `id` without letting go, steps it once through accessibility, and returns the
        /// workspace the step reached: it must be there, with no preview left on the live box.
        static func stepAfterPress(_ id: String) async throws -> DesignWorkspace {
            let live = DesignLiveDrag()
            let window = DesignWindow(seed: DesignGradientSeed.cards(selecting: "node-2"), live: live)
            let w = RenderBudgetWindow(window.allowsWindowActivationEvents(), size: CGSize(width: 1280, height: 1200))
            defer { w.close() }
            try await w.settle(800)
            let bar = try #require(await w.element(id), "no \(id)")
            w.send(.leftMouseDown, at: CGPoint(x: bar.midX, y: bar.midY))
            try await w.settle(200)
            DesignWindow.lastWorkspace = nil
            #expect(try await w.adjust(id, steps: 1), "\(id) takes no accessibility step")
            try await w.settle(400)
            #expect(live.workspace == nil, "the step stayed a preview on the live box")
            return try #require(DesignWindow.lastWorkspace, "the step never reached the window")
        }
    }
}
#endif
