// SuiteAgentActivitySnapshots.swift: SuiteUI's AgentActivityList (the AI tab)
// on its own, with a request whose steps include one that changed no layer
// (a selection) and a loose request that changed none. Those two rows draw no
// eye, their slot left empty so the other eyes keep one column. Writes
// suiteui-agent-activity-light/-dark.png. macOS only.
import Foundation
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteAgentActivitySnapshots {
    @Test func layerlessRowsDrawNoEye() throws {
        let requests = AgentRequests.group([
            AgentStepRecord(id: 1, name: "Add Layer", client: "claude", request: "Birds",
                            date: Date(timeIntervalSince1970: 0), layers: ["l1"]),
            AgentStepRecord(id: 2, name: "Select All", client: "claude", request: "Birds",
                            date: Date(timeIntervalSince1970: 20)),
            AgentStepRecord(id: 3, name: "Paint", client: "claude", request: "Birds",
                            date: Date(timeIntervalSince1970: 30), layers: ["l1"]),
            AgentStepRecord(id: 4, name: "Crop", client: "cursor", date: Date(timeIntervalSince1970: 3600)),
        ])
        #expect(AgentActivityList.decorations(requests, timeZone: .gmt)["agent.4"]?.showsEye == false)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                AgentActivityList(requests: requests, layerNames: ["l1": "Birds"], hidden: [], expanded: ["agent.1"],
                                  timeZone: .gmt) { _ in }
                    .frame(width: SuiteSize.editorPanelWidth, height: 220)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "suiteui-agent-activity-\(scheme.name)", scheme: scheme)
        }
    }
}
