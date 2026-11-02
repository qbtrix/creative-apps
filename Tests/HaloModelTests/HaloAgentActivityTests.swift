// HaloAgentActivityTests.swift: Halo's AI-tab adapter: an agent's steps as one
// request with the layers they touched, a user's steps left out, and the
// one-layer pick across compositions.
import SuiteKernel
import Testing

@testable import HaloModel

@Suite struct HaloAgentActivityTests {
    private func project() throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("two-comps")))
        return project
    }

    @Test func agentStepsBecomeOneRequestWithTheirLayers() throws {
        var model = try project()
        model.renameLayer("comp-1-layer-2", to: "Backdrop")
        #expect(model.agentRequests.isEmpty, "a user's steps listed as an agent's")
        let before = Set(model.compositions.flatMap(\.layers).map(\.id))
        StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            _ = model.setHistoryRequest("Retitle")
            model.renameLayer("comp-1-layer-3", to: "Logo")
            model.newLayer(.solid)
            _ = model.setHistoryRequest(nil)
        }
        let added = try #require(model.compositions.flatMap(\.layers).map(\.id).first { !before.contains($0) })
        let requests = model.agentRequests
        #expect(requests.count == 1, "\(requests)")
        let retitle = try #require(requests.first)
        #expect(retitle.title == "Retitle" && retitle.client == "claude" && retitle.isSpan)
        #expect(retitle.steps.count == 2 && retitle.date > .distantPast)
        #expect(Set(retitle.layers) == ["comp-1-layer-3", added], "\(retitle.layers)")
        #expect(model.layerNamesByID["comp-1-layer-3"] == "Logo")
    }

    @Test func selectPicksOneLiveLayerSwitchingComposition() throws {
        var model = try project()
        model.selectLayers(["gone", "comp-1-layer-3", "comp-1-layer-2"])
        #expect(model.selectedCompositionID == "comp-1" && model.selectedLayerID == "comp-1-layer-3")
        model.selectLayers(["comp-2-layer-2"])
        #expect(model.selectedCompositionID == "comp-2" && model.selectedLayerID == "comp-2-layer-2")
        model.selectLayers(["gone"])
        #expect(model.selectedLayerID == "comp-2-layer-2", "an all-gone pick dropped the selection")
    }

    @Test func aLaterUserEditStaysOutOfAnOlderRequest() throws {
        var model = try project()
        StepOrigin.$current.withValue(.agent(client: "claude", request: nil)) {
            model.renameLayer("comp-1-layer-3", to: "Logo")
        }
        model.renameLayer("comp-1-layer-2", to: "Backdrop")
        #expect(model.agentRequests.first?.layers == ["comp-1-layer-3"], "\(model.agentRequests)")
    }
}
