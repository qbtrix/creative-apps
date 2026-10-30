// LibraryAgentTabSnapshots.swift: Library's sidebar on its AI tab: two agent
// requests on SuiteUI's AgentActivityList, list only (no eye, no layers),
// the first one open to its steps, and the empty tab. Writes
// library-ai-tab-light/-dark.png and library-ai-tab-empty-light/-dark.png.
// macOS only.
import Foundation
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryAgentTabSnapshots {
    @Test func requests() throws {
        let requests = AgentRequests.group([
            AgentStepRecord(id: 1, name: "Set Rating", client: "claude", date: Date(timeIntervalSince1970: 0)),
            AgentStepRecord(id: 2, name: "New Collection", client: "claude", date: Date(timeIntervalSince1970: 30)),
            AgentStepRecord(id: 3, name: "Set Flag", client: "cursor", date: Date(timeIntervalSince1970: 3600)),
        ])
        try snapshots(
            AgentActivityList(requests: requests, layerNames: [:], hidden: [], expanded: ["agent.1"],
                              timeZone: TimeZone(identifier: "UTC") ?? .current, showsEye: false) { _ in },
            name: "library-ai-tab")
    }

    @Test func empty() throws {
        var model = LibraryCatalog()
        model.load(LibraryFixtures.photos(named: "shoot"))
        try snapshots(
            AgentSidebarTabs("Library", id: "library.sidebar.tabs", tab: .ai) { EmptyView() } ai: {
                AgentActivityList(requests: model.agentRequests, layerNames: [:], hidden: [], showsEye: false) { _ in }
            }, name: "library-ai-tab-empty")
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
