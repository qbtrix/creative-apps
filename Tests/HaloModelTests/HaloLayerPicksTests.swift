// HaloLayerPicksTests.swift: the LAYERS list multi-selects through the
// kernel's Selection. A toggle adds or drops a layer, an extend adds the run
// from the anchor in list order, the selected layer is always the last
// pick, a plain select drops the picks, Delete removes every picked layer in
// one "Delete Layer" step, and `layer.pick` runs the same through the
// catalog. Linux-safe.
import SuiteKernel
import Testing
@testable import HaloModel

struct HaloLayerPicksTests {
    private func project() throws -> (HaloProject, [String]) {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        let ids = try #require(project.selectedComposition?.layers.map(\.id))
        project.selectLayer(ids[0])
        return (project, ids)
    }

    @Test func picksToggleAndExtend() throws {
        var (p, ids) = try project()
        #expect(p.pickedLayerIDs == [ids[0]])
        p.pickLayer(ids[2], .toggle)
        #expect(p.pickedLayerIDs == [ids[0], ids[2]] && p.selectedLayerID == ids[2])
        p.pickLayer(ids[2], .toggle)
        #expect(p.pickedLayerIDs == [ids[0]] && p.selectedLayerID == ids[0])
        p.pickLayer(ids[2], .extend)
        #expect(p.pickedLayerIDs == Set(ids) && p.selectedLayerID == ids[2])
        p.selectLayer(ids[1])
        #expect(p.pickedLayerIDs == [ids[1]])
        p.pickLayer("nosuch", .toggle)
        #expect(p.pickedLayerIDs == [ids[1]])
    }

    @Test func deleteRemovesEveryPick() throws {
        var (p, ids) = try project()
        p.pickLayer(ids[1], .toggle)
        p.deleteSelectedLayer()
        #expect(p.selectedComposition?.layers.map(\.id) == [ids[2]])
        #expect(p.history.undoTitle == "Undo Delete Layer" && p.pickedLayerIDs == [ids[2]])
        p.undo()
        #expect(p.selectedComposition?.layers.map(\.id) == ids)
    }

    @Test func pickRunsThroughTheCatalog() throws {
        var (p, ids) = try project()
        _ = try HaloProject.catalog.run("layer.pick", params: .object(["id": .string(ids[1]), "pick": .string("toggle")]), on: &p)
        #expect(p.pickedLayerIDs == [ids[0], ids[1]])
        #expect(throws: (any Error).self) {
            _ = try HaloProject.catalog.run("layer.pick", params: .object(["id": .string(ids[1]), "pick": .string("swap")]), on: &p)
        }
    }
}
