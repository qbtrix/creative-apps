// PhotoAgentActivityTests.swift: Photo's AI-tab adapter: the eye as one undo
// step, selection of exactly the live ids, and a step's layers from its payload.
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
        #expect(model.layers.allSatisfy(\.isVisible))
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
        #expect(model.agentRequests.isEmpty, "no step has an agent origin before #6028")
    }
}
