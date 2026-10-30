// AgentRequestsTests.swift: AgentRequests.group, the AI tab's request rule:
// spans group by title, loose steps by client within 60 s, newest first.
import Foundation
import SuiteKernel
import Testing

@Suite struct AgentRequestsTests {
    private func step(_ id: Int, _ name: String, client: String = "claude", request: String? = nil,
                      at seconds: Double, layers: [String] = []) -> AgentStepRecord {
        AgentStepRecord(id: id, name: name, client: client, request: request,
                        date: Date(timeIntervalSince1970: seconds), layers: layers)
    }

    @Test func spanGroupsByTitleNewestFirst() {
        let requests = AgentRequests.group([
            step(1, "Add Layer", request: "Make a poster", at: 0, layers: ["a"]),
            step(2, "Paint", request: "Make a poster", at: 500, layers: ["a", "b"]),
            step(3, "Crop", request: "Crop it", at: 501),
        ])
        #expect(requests.map(\.title) == ["Crop it", "Make a poster"])
        #expect(requests[1].steps.map(\.name) == ["Add Layer", "Paint"])
        #expect(requests[1].layers == ["a", "b"] && requests[1].isSpan && requests[1].id == "agent.1")
        #expect(requests[1].date == Date(timeIntervalSince1970: 500))
    }

    @Test func looseStepsJoinPerClientWithinAMinute() {
        let requests = AgentRequests.group([
            step(1, "Paint", at: 0), step(2, "Blur", at: 60), step(3, "Hue", at: 121),
            step(4, "Fill", client: "cursor", at: 122),
        ])
        #expect(requests.map(\.title) == ["Fill", "Hue", "Paint"])
        #expect(requests.map(\.steps.count) == [1, 1, 2])
        #expect(requests.allSatisfy { !$0.isSpan })
    }

    @Test func aSpanNeverAbsorbsLooseSteps() {
        let requests = AgentRequests.group([
            step(1, "Paint", request: "Poster", at: 0), step(2, "Blur", at: 1), step(3, "Hue", request: "Poster", at: 2),
        ])
        #expect(requests.map(\.title) == ["Poster", "Blur", "Poster"])
        #expect(AgentRequests.group([]).isEmpty)
    }
}
