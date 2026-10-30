// RenderBudgetDesignAgentWorkingTests.swift (render budget row "an agent step
// while the AI is working: no more window bodies than a person's step"): the
// real Design window seeded with the `crowd` fixture (2,000 layers), on the
// render budget harness. Agent steps go in as a live command's result does
// (DesignWindow's DEBUG `liveAdopt`, `.adoptLive`). Idle costs 0 window and 0
// working-mark bodies; an agent step inside an open request costs no more
// DesignWindow + DesignEditor bodies than a person's same step, plus at most
// two of the mark's own; a second of working (the mark pulsing) and the
// linger after `history.end` cost 0 window bodies. The mark shows "AI is
// working: <request>" while it works and is gone after the linger. Nested
// in BodyCountSuites: it reads global body counters. Debug builds only.
// macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignAgentWorkingTests {
        static let mark = "design.sidebar.tabs.ai.working"

        @Test(.timeLimit(.minutes(3))) func workingCostsOnlyTheMark() async throws {
            let w = RenderBudgetWindow(DesignWindow(seed: DesignFixtures.crowd))
            defer { w.close() }
            try await w.settle(800)
            #if DEBUG
            let window = { () -> Int? in DesignWindow.bodyRuns + DesignEditor.bodyRuns }
            let marks = { () -> Int? in AgentWorkingMark.bodyRuns }
            let live = try #require(DesignWindow.liveAdopt, "the window set no live hook")
            let ids = live.read().pages.first.map { $0.nodes.prefix(2).map(\.id) } ?? []
            try #require(ids.count == 2, "the crowd page has no two layers")
            /// One step on the window's workspace, recorded as `origin` makes it, adopted as a live result.
            func step(_ origin: StepOrigin, _ edit: (inout DesignWorkspace) throws -> Void) async throws {
                var model = live.read()
                try StepOrigin.$current.withValue(origin) { try edit(&model) }
                try await w.ticks(1) { _ in live.write(model) }
            }
            let agent = StepOrigin.agent(client: "claude", request: nil)
            try await w.settle(untilStable: window)

            let idleWindow = try await w.measure("design idle, crowd", bodies: window) { try await w.settle(1000) }
            #expect(idleWindow.bodies == 0, "idle ran window bodies: \(idleWindow)")
            let idleMarks = try await w.measure("design idle mark, crowd", bodies: marks) { try await w.settle(1000) }
            #expect(idleMarks.bodies == 0, "idle ran the working mark: \(idleMarks)")
            #expect(w.elementNow(Self.mark) == nil, "the mark shows while no agent works")

            let person = try await w.measure("design person step, crowd", bodies: window) {
                try await step(.user) { try $0.setNodeHidden(ids[0], true) }
            }
            try await w.settle(untilStable: window)
            try await step(agent) { _ = $0.setHistoryRequest("AI: Cards") }
            try await w.settle(untilStable: window)

            let markBefore = AgentWorkingMark.bodyRuns
            let agentStep = try await w.measure("design agent step while working, crowd", bodies: window) {
                try await step(agent) { try $0.setNodeHidden(ids[1], true) }
            }
            let markRuns = AgentWorkingMark.bodyRuns - markBefore
            print("RENDER-BUDGET design agent step: window bodies \(agentStep.bodies ?? -1) vs person \(person.bodies ?? -1), mark bodies \(markRuns)")
            #expect((agentStep.bodies ?? .max) <= (person.bodies ?? 0), "agent \(agentStep) vs person \(person)")
            #expect(markRuns <= 2, "the mark ran \(markRuns) bodies for one step")
            #expect(w.label(Self.mark) == "AI is working: AI: Cards", "\(w.label(Self.mark) ?? "no mark")")

            let working = try await w.measure("design working second, crowd", bodies: window) { try await w.settle(1000) }
            #expect(working.bodies == 0, "the working mark ran window bodies: \(working)")

            try await step(agent) { _ = $0.setHistoryRequest(nil) }
            #expect(w.label(Self.mark) == "AI is working: AI: Cards", "the mark left before its linger")
            let linger = try await w.measure("design linger, crowd", bodies: window) {
                try await w.settle(Int(AgentWork.linger * 1000) + 400)
            }
            #expect(linger.bodies == 0, "the linger ran window bodies: \(linger)")
            #expect(w.elementNow(Self.mark) == nil, "the mark stayed after its linger")
            #endif
        }
    }
}
#endif
