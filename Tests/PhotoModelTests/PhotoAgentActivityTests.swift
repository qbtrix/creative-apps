// PhotoAgentActivityTests.swift: Photo's AI-tab adapter: the eye as one undo
// step, selection of exactly the live ids, and a step's layers from its payload.
import Foundation
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite struct PhotoAgentActivityTests {
    @Test func eyeHidesAllAsOneStepAndUndoes() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let ids = model.layers.map(\.id)
        let before = model.historySteps.count
        model.setLayersHidden(ids + ["gone"], hidden: true)
        #expect(model.layers.allSatisfy { !$0.isVisible })
        #expect(model.historySteps.count == before + 1 && model.historySteps.last == "Hide Agent Layers")
        model.setLayersHidden(ids, hidden: true)
        #expect(model.historySteps.count == before + 1, "a no-op recorded a step")
        model.undo()
        #expect(model.layers.allSatisfy { $0.isVisible })
    }

    @Test func selectPicksLiveIDsInListOrder() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let ids = model.layers.map(\.id)
        model.selectLayers([ids[0], "gone", ids[2]])
        #expect(Set(model.selectedLayerIDs) == [ids[0], ids[2]])
        model.selectLayers(["gone"])
        #expect(Set(model.selectedLayerIDs) == [ids[0], ids[2]], "an all-gone pick dropped the selection")
    }

    @Test func payloadNamesTheLayersAStepTouched() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let before = model.layers
        #expect(PhotoEdit.tiles(layer: "a", [:]).layerIDs(now: before) == ["a"])
        #expect(PhotoEdit.layers(before, selected: nil).layerIDs(now: before).isEmpty)
        model.toggleVisibility(before[1].id)
        model.addLayer()
        let touched = PhotoEdit.layers(before, selected: nil).layerIDs(now: model.layers)
        let added = try #require(model.layers.map(\.id).first { id in !before.contains { $0.id == id } })
        #expect(Set(touched) == [before[1].id, added])
        #expect(PhotoEdit.group([.tiles(layer: "a", [:]), .maskTiles(layer: "a", [:])]).layerIDs(now: []) == ["a"])
        #expect(model.agentRequests.isEmpty, "a user's steps listed as an agent's")
    }

    @Test func agentStepsBecomeOneRequestWithTheirLayers() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let first = try #require(model.layers.first?.id)
        model.toggleVisibility(first)
        StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            _ = model.setHistoryRequest("Make a poster")
            model.toggleVisibility(first)
            model.addLayer()
            _ = model.setHistoryRequest(nil)
        }
        let requests = model.agentRequests
        #expect(requests.count == 1, "\(requests)")
        let poster = try #require(requests.first)
        #expect(poster.title == "Make a poster" && poster.client == "claude" && poster.isSpan)
        #expect(poster.steps.count == 2 && poster.date > .distantPast)
        #expect(poster.layers.contains(first) && poster.layers.count == 2)
    }
}
