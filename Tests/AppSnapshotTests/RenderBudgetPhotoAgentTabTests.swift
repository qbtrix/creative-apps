// RenderBudgetPhotoAgentTabTests.swift (#6029, render budget row "open the
// sidebar's AI tab: 0 window bodies, 0 canvas shows"): the real Photo window
// on the `large` fixture, hosted on the render budget harness through
// RenderBudgetPhotoFacetsTests' host. Picking the sidebar's AI segment (as its click does)
// switches AgentSidebarTabs' own state, so PhotoEditor's body runs 0 times
// and the canvas view's `show` is called 0 times; the tab shows its empty
// state. Opening a request row is the AI list's own state too; it is covered
// here once History records agent steps (#6028). Debug builds only. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor @Suite(.serialized) struct RenderBudgetPhotoAgentTabTests {
    @Test(.timeLimit(.minutes(3))) func openingTheAITabRendersNothing() async throws {
        let session = PhotoSession(try PhotoWorkspace.fixture(.large))
        let (w, tally, canvas, _) = try await RenderBudgetPhotoFacetsTests.host(session)
        defer { w.close() }
        #expect(await w.element("photo.sidebar.tabs.ai") != nil, "the sidebar shows no AI tab")
        let shows = canvas.showCalls
        let step = try await w.measure("photo sidebar AI tab, large", bodies: RenderBudgetPhotoFacetsTests.editor(tally)) {
            // A synthetic click waits in NSSegmentedControl's tracking loop; pick the segment as its click would.
            try await w.ticks(1) { _ in #expect(w.select(segment: "photo.sidebar.tabs.ai"), "no AI segment") }
        }
        try await w.settle()
        #expect(await w.element("suite.agent.empty") != nil, "the AI tab didn't open")
        #expect(step.bodies == 0, "\(step)")
        #expect(canvas.showCalls - shows == 0)
    }

    @Test(.timeLimit(.minutes(3))) func openingARequestRowRendersNothing() async throws {
        var model = try PhotoWorkspace.fixture(.large)
        StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            _ = model.setHistoryRequest("AI: Birds")
            model.addLayer()
            model.addLayer()
            _ = model.setHistoryRequest(nil)
        }
        let request = try #require(model.agentRequests.first, "the agent's steps made no request")
        let session = PhotoSession(model)
        let (w, tally, canvas, _) = try await RenderBudgetPhotoFacetsTests.host(session)
        defer { w.close() }
        try await w.ticks(1) { _ in #expect(w.select(segment: "photo.sidebar.tabs.ai"), "no AI segment") }
        try await w.settle()
        let naming = AgentActivityList.naming
        let disclosure = try #require(await w.element(naming.disclosure(request.id)), "the request row has no disclosure")
        let firstStep = try #require(request.steps.first)
        let stepRow = naming.row(AgentActivityList.stepID(request, firstStep))
        #expect(w.elementNow(stepRow) == nil, "the request opened before its press")
        let shows = canvas.showCalls
        let step = try await w.measure("photo AI request row open, large", bodies: RenderBudgetPhotoFacetsTests.editor(tally)) {
            try await w.ticks(1) { _ in w.click(at: CGPoint(x: disclosure.midX, y: disclosure.midY)) }
        }
        try await w.settle()
        #expect(await w.element(stepRow) != nil, "the press never opened the request")
        #expect(step.bodies == 0, "\(step)")
        #expect(canvas.showCalls - shows == 0)
    }
}
#endif
