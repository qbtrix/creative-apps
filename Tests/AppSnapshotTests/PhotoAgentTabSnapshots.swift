// PhotoAgentTabSnapshots.swift: Photo's sidebar on its AI tab (#6029): two
// agent requests on SuiteUI's AgentActivityList, the poster one open to its
// steps and layers, and the empty tab. Writes photo-ai-tab-light/-dark.png and
// photo-ai-tab-empty-light/-dark.png. macOS only.
import Foundation
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoAgentTabSnapshots {
    @Test func requests() throws {
        let model = try PhotoWorkspace.fixture(.layered)
        let ids = model.layers.map(\.id)
        let requests = AgentRequests.group([
            AgentStepRecord(id: 1, name: "Add Layer", client: "claude", request: "Make a poster",
                            date: Date(timeIntervalSince1970: 0), layers: [ids[0]]),
            AgentStepRecord(id: 2, name: "Paint", client: "claude", request: "Make a poster",
                            date: Date(timeIntervalSince1970: 30), layers: [ids[0], ids[1]]),
            AgentStepRecord(id: 3, name: "Gaussian Blur", client: "cursor", date: Date(timeIntervalSince1970: 3600),
                            layers: [ids[2]]),
        ])
        let names = Dictionary(model.layers.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        try snapshots(
            AgentActivityList(requests: requests, layerNames: names, hidden: [ids[1]], expanded: ["agent.1"],
                              timeZone: TimeZone(identifier: "UTC") ?? .current) { _ in },
            name: "photo-ai-tab")
    }

    @Test func empty() throws {
        let model = try PhotoWorkspace.fixture(.layered)
        try snapshots(PhotoSidebarTabs(model: model, perform: { _ in }, tab: .ai), name: "photo-ai-tab-empty")
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
