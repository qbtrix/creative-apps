// HaloViewerStateTests.swift: the viewer's Model values on the fixtures: the
// artboard summary lists visible, non-null layers bottom first (a text layer
// with its words), the draw list carries a viewer drag's preview on only the
// dragged layer, and the selected layer's header names its parent. Runs on
// Linux and macOS.
@testable import HaloModel
import Testing

/// `name` loaded on the fake services, first composition selected.
private func fixture(_ name: String) throws -> HaloProject {
    var project = HaloProject(services: .fake)
    project.restore(try #require(HaloFixtures.project(name)))
    return project
}

struct HaloViewerStateTests {
    @Test func summaryListsVisibleLayersBottomFirst() throws {
        var project = try fixture("three-layers")
        project.scrub(to: 12)
        #expect(project.viewerSummary == "Frame 12: Background, Badge")
        project.scrub(to: 30)
        #expect(project.viewerSummary == "Frame 30: Background, Badge, Title: Hello Halo")
    }

    @Test func summaryOfAnEmptyCompositionAndOfNone() throws {
        #expect(try fixture("empty").viewerSummary == "Frame 0: no layers")
        #expect(HaloProject(services: .fake).viewerSummary == "No composition")
        #expect(HaloProject(services: .fake).viewerDrawList == nil)
    }

    @Test func aViewerDragMovesOnlyThatLayer() throws {
        var project = try fixture("three-layers")
        project.scrub(to: 30)
        let before = try #require(project.viewerDrawList)
        project.viewerDrag = HaloViewerDragState(
            layerID: "comp-1-layer-3", start: HaloPoint(x: 0, y: 0), delta: HaloPoint(x: 100, y: 0))
        let after = try #require(project.viewerDrawList)
        #expect(after == before.offsetting("comp-1-layer-3", by: HaloPoint(x: 100, y: 0)))
        #expect(after != before)
        let moved = after.items.filter { item in before.items.first { $0.layerID == item.layerID } != item }
        #expect(moved.map(\.layerID) == ["comp-1-layer-3"])
        #expect(after.items.map(\.layerID) == before.items.map(\.layerID))
    }

    @Test func headerNamesTheParentAndIsNilWithNoLayer() throws {
        var project = try fixture("three-layers")
        #expect(project.selectedLayerHeader == nil)
        var doc = project.document
        doc.compositions[0].layers[1].parentID = "comp-1-layer-1"
        doc.selectedLayerID = "comp-1-layer-3"
        project.restore(doc)
        #expect(project.selectedLayerHeader?.parent == "Rig")
    }
}
