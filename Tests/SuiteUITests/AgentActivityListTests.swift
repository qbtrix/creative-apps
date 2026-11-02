// AgentActivityListTests.swift: the AI tab's rows over LayerTreeList: a closed
// request is one row, an open one lists its steps then its layers one level in,
// the eye state and the caption; which request reads live while an agent
// works, and the working mark's VoiceOver label.
import Foundation
import SuiteKernel
import Testing

@testable import SuiteUI

@Suite struct AgentActivityListTests {
    static let requests = AgentRequests.group([
        AgentStepRecord(id: 1, name: "Add Layer", client: "claude", request: "Make a poster",
                        date: Date(timeIntervalSince1970: 0), layers: ["l1"]),
        AgentStepRecord(id: 2, name: "Paint", client: "claude", request: "Make a poster",
                        date: Date(timeIntervalSince1970: 30), layers: ["l1", "l2"]),
        AgentStepRecord(id: 3, name: "Blur", client: "cursor", date: Date(timeIntervalSince1970: 3600)),
    ])

    @Test func rowsOpenToStepsThenLayers() {
        let closed = AgentActivityList.rows(Self.requests, expanded: [], names: [:], hidden: [])
        #expect(closed.map(\.name) == ["Blur", "Make a poster"] && closed.allSatisfy { $0.holdsChildren })
        let open = AgentActivityList.rows(Self.requests, expanded: ["agent.1"], names: ["l1": "Title"],
                                          hidden: ["l1", "l2"])
        #expect(open.map(\.name) == ["Blur", "Make a poster", "Add Layer", "Paint", "Title", "l2"])
        #expect(open.map(\.depth) == [0, 0, 1, 1, 1, 1])
        #expect(open[1].isHidden && open[1].isExpanded && open[4].inheritsHidden)
        #expect(!open[0].isHidden, "a request with no layers reads hidden")
    }

    @Test func eachRowStandsForItsLayers() {
        let r = Self.requests
        #expect(AgentActivityList.layers(of: "agent.1", in: r) == ["l1", "l2"])
        #expect(AgentActivityList.layers(of: "agent.1.step.1", in: r) == ["l1"])
        #expect(AgentActivityList.layers(of: "agent.1.layer.l2", in: r) == ["l2"])
        #expect(AgentActivityList.layers(of: "agent.3", in: r).isEmpty)
    }

    @Test func captionNamesClientTimeAndSteps() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let caption = AgentActivityList.decorations(Self.requests, timeZone: utc)["agent.1"]?.caption ?? ""
        #expect(caption.hasPrefix("claude · ") && caption.hasSuffix(" · 2 steps"))
        #expect(AgentActivityList.decorations(Self.requests, timeZone: utc)["agent.3"]?.caption?.hasSuffix("1 step") == true)
    }

    @Test func undoHelpSaysWhyOrNothing() {
        let (open, loose) = (Self.requests[1], Self.requests[0])
        #expect(AgentActivityList.undoHelp(open, newest: true) == nil)
        #expect(AgentActivityList.undoHelp(open, newest: false) == "Undo the newer requests first.")
        #expect(AgentActivityList.undoHelp(loose, newest: true)?.contains("history.begin") == true)
        #expect(AgentActivityList.undoHelp(open, newest: true, app: "No.") == "No.")
    }

    @Test func liveRequestIsTheNewestWhileItWorks() {
        let spanFirst = AgentRequests.group([
            AgentStepRecord(id: 3, name: "Blur", client: "cursor", date: Date(timeIntervalSince1970: 0)),
            AgentStepRecord(id: 4, name: "Add Layer", client: "claude", request: "Poster", date: Date(timeIntervalSince1970: 9)),
        ])
        #expect(AgentActivityList.liveRequest(spanFirst, shown: nil) == nil, "idle read live")
        #expect(AgentActivityList.liveRequest(spanFirst, shown: AgentWork(request: "Poster", lastStep: 4)) == "agent.4")
        #expect(AgentActivityList.liveRequest(spanFirst, shown: AgentWork(request: "Other")) == nil, "another span read live")
        #expect(AgentActivityList.liveRequest(Self.requests, shown: AgentWork(lastStep: 3)) == "agent.3", "a loose step's request")
        #expect(AgentActivityList.liveRequest(Self.requests, shown: AgentWork(lastStep: 9)) == nil, "a step it lacks")
        let live = AgentActivityList.decorations(spanFirst, timeZone: .gmt, live: "agent.4")
        #expect(live["agent.4"]?.live == true && live["agent.3"]?.live == false)
    }

    @Test func markSaysWhatTheAgentIsDoing() {
        #expect(AgentWorkingMark.label(AgentWork(request: "AI: Birds")) == "AI is working: AI: Birds")
        #expect(AgentWorkingMark.label(AgentWork(lastStep: 2)) == "AI is working")
    }
}
