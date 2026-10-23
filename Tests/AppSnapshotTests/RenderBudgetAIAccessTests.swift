// RenderBudgetAIAccessTests.swift (afterglow-mcp MC-13): what the AI access
// approval flow costs a real app window (Tests/render-budgets.md), through the
// harness (RenderBudgetHarness.swift), on FakeAIAccess. On Flare's New Sample
// Animation with Ellipse chosen it drags 120 samples across the canvas, then
// a demo client asks: AIAccessCenter begins the approval sheet on the window
// and Allow Once closes it and puts the "Controlled by" chip in the title bar
// (one measured step), then the same drag runs with the chip showing; Stop
// takes the chip out and the next request asks again. The title-bar chip
// needs a titled window, so the harness window gets `.titled` before the first
// measure. Nested in BodyCountSuites, as every suite that reads a body
// counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SuiteModel
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetAIAccessTests {
        @Test(.timeLimit(.minutes(2))) func sheet() async throws {
            let center = AIAccessCenter()
            center.start(app: .flare, arguments: [])
            let w = try await Self.window()
            defer { w.close() }
            let client = FakeAIAccess.demoClient
            let ask = try await w.measure("ai access sheet appear and Allow Once", bodies: Self.bodies) {
                try await w.ticks(1) { _ in center.request(client: client, command: "flare.ellipse.add", in: w.window) }
                try await w.settle(300)
                #expect(w.window.attachedSheet != nil, "the request began no sheet on the window")
                try await w.ticks(1) { _ in center.decide(.allowOnce) }
            }
            try await w.settle(300)
            #expect(w.window.attachedSheet == nil, "the sheet stayed after Allow Once")
            #expect(center.access?.connectedClient == client, "Allow Once didn't connect the client")
            #expect(w.window.titlebarAccessoryViewControllers.count == 1, "no chip after Allow Once")
            // The sheet is its own window and the chip its own hosting view: the app window's body runs at most
            // for the sheet's key change and its end. Target: 0.
            expectBodies(ask, atMost: 2, target: 0)

            // Stop: the chip goes and the next request asks again.
            center.stop()
            #expect(center.access?.connectedClient == nil, "Stop left the client connected")
            #expect(w.window.titlebarAccessoryViewControllers.isEmpty, "the chip stayed after Stop")
            center.request(client: client, in: w.window)
            #expect(center.access?.pending?.client == client, "the request after Stop didn't ask again")
            #expect(w.window.attachedSheet != nil, "the request after Stop began no sheet")
            center.decide(.deny)
            try await w.settle(300)
        }

        @Test(.timeLimit(.minutes(2))) func chip() async throws {
            let center = AIAccessCenter()
            center.start(app: .flare, arguments: [])
            let w = try await Self.window()
            defer { w.close() }
            let plain = try await w.measure("flare canvas ellipse drag, no chip", bodies: Self.bodies) {
                try await w.drag(from: CGPoint(x: 600, y: 420), by: CGVector(dx: 200, dy: 80))
            }
            center.request(client: FakeAIAccess.demoClient, in: w.window)
            try await w.settle(300)
            center.decide(.allowOnce)
            try await w.settle(300)
            #expect(w.window.titlebarAccessoryViewControllers.count == 1, "no chip to drag beside")
            let chipped = try await w.measure("flare canvas ellipse drag, chip showing", bodies: Self.bodies) {
                try await w.drag(from: CGPoint(x: 400, y: 300), by: CGVector(dx: 200, dy: 80))
            }
            // The chip adds no window bodies to a drag; the drag's own bound is RenderBudgetFlareTests' 3.
            if let with = chipped.bodies, let without = plain.bodies {
                #expect(with <= without, "the chip added window bodies to a canvas drag: \(chipped) against \(plain)")
            }
            expectBodies(chipped, atMost: 3, target: 3)
            center.stop()
            #expect(w.window.titlebarAccessoryViewControllers.isEmpty, "the chip stayed after Stop")
        }

        /// Flare's window on New Sample Animation with Ellipse chosen, in a titled harness window, settled.
        static func window() async throws -> RenderBudgetWindow<FlareWindow> {
            var model = FlareWorkspace(services: .built)
            model.newSampleAnimation()
            model.selectTool(.ellipse)
            let w = RenderBudgetWindow(FlareWindow(model: model))
            w.window.styleMask.insert(.titled)
            try await w.settle(500)
            return w
        }

        /// FlareWindow's body runs; nil in release, which has no counter.
        static func bodies() -> Int? {
            #if DEBUG
            return FlareWindow.bodyRuns
            #else
            return nil
            #endif
        }
    }
}
#endif
