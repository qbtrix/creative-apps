// HaloAgentTabSnapshots.swift: Halo's sidebar on its AI tab: two agent
// requests on SuiteUI's AgentActivityList over the `three-layers` layers,
// with no eye (Halo layers can't hide), the first one open to its steps and
// layers, and the empty tab. Writes halo-ai-tab-light/-dark.png and
// halo-ai-tab-empty-light/-dark.png. macOS only.
import Foundation
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp
@testable import HaloModel

@MainActor
@Suite struct HaloAgentTabSnapshots {
    private func project() throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("three-layers")))
        return project
    }

    @Test func requests() throws {
        let model = try project()
        let requests = AgentRequests.group([
            AgentStepRecord(id: 1, name: "Rename Layer", client: "claude", request: "Retitle the intro",
                            date: Date(timeIntervalSince1970: 0), layers: ["comp-1-layer-4"]),
            AgentStepRecord(id: 2, name: "Set Opacity", client: "claude", request: "Retitle the intro",
                            date: Date(timeIntervalSince1970: 30), layers: ["comp-1-layer-4", "comp-1-layer-3"]),
            AgentStepRecord(id: 3, name: "New Layer", client: "cursor", date: Date(timeIntervalSince1970: 3600),
                            layers: ["comp-1-layer-2"]),
        ])
        try snapshots(
            AgentActivityList(requests: requests, layerNames: model.layerNamesByID, hidden: [], expanded: ["agent.1"],
                              timeZone: TimeZone(identifier: "UTC") ?? .current, showsEye: false) { _ in },
            name: "halo-ai-tab")
    }

    @Test func empty() throws {
        try snapshots(
            AgentSidebarTabs("Compositions", id: HaloProject.sidebarTabsControl, tab: .ai) { EmptyView() } ai: {
                AgentActivityList(requests: [], layerNames: [:], hidden: [], showsEye: false) { _ in }
            }, name: "halo-ai-tab-empty")
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
