// DesignAgentActivityTests.swift: Design's AI-tab adapter: an agent's steps as
// one request with the nodes they touched (a child's edit not listing its
// group), the eye as one undo step, and selection on one page.
import Foundation
import SuiteKernel
import Testing

@testable import DesignModel

@Suite struct DesignAgentActivityTests {
    @Test func agentStepsBecomeOneRequestWithTheirNodes() throws {
        var model = DesignFixtures.cards
        try model.setNodeHidden("node-2", true)
        #expect(model.agentRequests.isEmpty, "a user's steps listed as an agent's")
        var added = ""
        try StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            _ = model.setHistoryRequest("Make cards")
            try model.setNodeHidden("node-7", true)
            added = try model.addNode(.rectangle, frame: DesignRect(x: 10, y: 10, width: 20, height: 20))
            _ = model.setHistoryRequest(nil)
        }
        let requests = model.agentRequests
        #expect(requests.count == 1, "\(requests)")
        let cards = try #require(requests.first)
        #expect(cards.title == "Make cards" && cards.client == "claude" && cards.isSpan)
        #expect(cards.steps.count == 2 && cards.date > .distantPast)
        #expect(Set(cards.layers) == ["node-7", added], "\(cards.layers)")
        #expect(model.layerNamesByID["node-7"] == "E1" && model.hiddenNodeIDs.contains("node-7"))
    }

    @Test func eyeHidesAllAsOneStepAndUndoes() throws {
        var model = DesignFixtures.cards
        let before = model.history.undo.count
        model.setLayersHidden(["node-2", "node-3", "gone"], hidden: true)
        #expect(model.hiddenNodeIDs.isSuperset(of: ["node-2", "node-3"]))
        #expect(model.history.undo.count == before + 1 && model.history.undo.last?.name == "Hide Agent Layers")
        model.setLayersHidden(["node-2", "node-3"], hidden: true)
        #expect(model.history.undo.count == before + 1, "a no-op recorded a step")
        model.undo()
        #expect(!model.hiddenNodeIDs.contains("node-2") && !model.hiddenNodeIDs.contains("node-3"))
    }

    @Test func selectPicksLiveNodesOnOnePage() throws {
        var model = DesignFixtures.twoPages
        model.selectLayers(["node-2", "gone", "node-3", "node-11"])
        #expect(model.selectedPageID == "page-1" && Set(model.selectedNodeIDs) == ["node-2", "node-3"])
        model.selectLayers(["node-11"])
        #expect(model.selectedPageID == "page-2" && model.selectedNodeIDs == ["node-11"])
        model.selectLayers(["gone"])
        #expect(model.selectedNodeIDs == ["node-11"], "an all-gone pick dropped the selection")
    }

    @Test func aLaterUserEditStaysOutOfAnOlderRequest() throws {
        var model = DesignFixtures.cards
        try StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            try model.setNodeHidden("node-2", true)
        }
        try model.setNodeHidden("node-3", true)
        #expect(model.agentRequests.first?.layers == ["node-2"], "\(model.agentRequests)")
    }
}

@Suite struct DesignAgentWorkTests {
    @Test func newestAgentLayersNameOnlyTheLastAgentStep() throws {
        var model = DesignFixtures.cards
        #expect(model.newestAgentLayers.isEmpty && model.agentWork == AgentWork())
        try StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            _ = model.setHistoryRequest("Make cards")
            try model.setNodeHidden("node-2", true)
            try model.setNodeHidden("node-3", true)
        }
        #expect(model.newestAgentLayers == ["node-3"], "\(model.newestAgentLayers)")
        #expect(model.agentWork.request == "Make cards" && model.agentWork.lastStep != nil)
        try model.setNodeHidden("node-4", true)
        #expect(model.newestAgentLayers.isEmpty, "a person's step lit as the agent's")
    }
}
