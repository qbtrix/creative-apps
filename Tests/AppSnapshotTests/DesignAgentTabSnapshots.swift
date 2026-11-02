// DesignAgentTabSnapshots.swift: Design's sidebar on its AI tab: two agent
// requests on SuiteUI's AgentActivityList over the `cards` nodes, the first
// one open to its steps and layers, and the empty tab; the AI tab mid-request
// (the live row's shimmer held still, as a snapshot draws it) and the
// sidebar's Layers tab idle and while an agent works (the AI segment's dot).
// Writes design-ai-tab-light/-dark.png, design-ai-tab-empty-light/-dark.png,
// design-ai-tab-working-light/-dark.png and
// design-sidebar-idle-light/-dark.png, design-sidebar-working-light/-dark.png.
// macOS only.
import DesignModel
import Foundation
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignAgentTabSnapshots {
    @Test func requests() throws {
        let model = DesignFixtures.cards
        let requests = AgentRequests.group([
            AgentStepRecord(id: 1, name: "Add Rectangle", client: "claude", request: "Lay out the cards",
                            date: Date(timeIntervalSince1970: 0), layers: ["node-2"]),
            AgentStepRecord(id: 2, name: "Change Fill", client: "claude", request: "Lay out the cards",
                            date: Date(timeIntervalSince1970: 30), layers: ["node-2", "node-3"]),
            AgentStepRecord(id: 3, name: "Align Left", client: "cursor", date: Date(timeIntervalSince1970: 3600),
                            layers: ["node-4"]),
        ])
        try snapshots(
            AgentActivityList(requests: requests, layerNames: model.layerNamesByID, hidden: ["node-3"],
                              expanded: ["agent.1"], timeZone: TimeZone(identifier: "UTC") ?? .current) { _ in },
            name: "design-ai-tab")
    }

    @Test func midRequest() throws {
        let model = DesignFixtures.cards
        let requests = AgentRequests.group([
            AgentStepRecord(id: 1, name: "Align Left", client: "cursor", date: Date(timeIntervalSince1970: 0), layers: ["node-4"]),
            AgentStepRecord(id: 2, name: "Add Rectangle", client: "claude", request: "Lay out the cards",
                            date: Date(timeIntervalSince1970: 3600), layers: ["node-2"]),
            AgentStepRecord(id: 3, name: "Change Fill", client: "claude", request: "Lay out the cards",
                            date: Date(timeIntervalSince1970: 3630), layers: ["node-2", "node-3"]),
        ])
        try snapshots(
            AgentActivityList(requests: requests, layerNames: model.layerNamesByID, hidden: [],
                              timeZone: TimeZone(identifier: "UTC") ?? .current,
                              work: AgentWork(request: "Lay out the cards", lastStep: 3)) { _ in },
            name: "design-ai-tab-working")
    }

    @Test func sidebarIdleAndWorking() throws {
        var working = DesignFixtures.cards
        _ = working.setHistoryRequest("Lay out the cards")
        try snapshots(DesignSidebarTabs(model: DesignFixtures.cards, perform: { _ in }), name: "design-sidebar-idle")
        try snapshots(DesignSidebarTabs(model: working, perform: { _ in }), name: "design-sidebar-working")
    }

    @Test func empty() throws {
        try snapshots(DesignSidebarTabs(model: DesignFixtures.cards, perform: { _ in }, tab: .ai), name: "design-ai-tab-empty")
    }

    private func snapshots(_ view: some View, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                view.frame(width: SuiteSize.editorPanelWidth, height: 280)
                    .background(SuiteColor.panel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
