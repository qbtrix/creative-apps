// HaloSelectKeyRefusalTests.swift: easing.select-key either picks the key it names or refuses in a sentence (#5832).
// A key on another layer selects that layer first, as a timeline diamond does; a frame with no key that starts a
// segment refuses and changes nothing, so the next animation.easing never meets a pick that silently didn't happen.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloSelectKeyRefusalTests {
    let catalog = HaloProject.catalog, ball = "comp-1-layer-2", floor = "comp-1-layer-1"

    func params(_ layerID: String, _ property: String, _ frame: Int) -> JSONValue {
        .object(["layerID": .string(layerID), "property": .string(property), "frame": .number(Double(frame)), "extending": .bool(false)])
    }

    @Test func aFrameWithNoSegmentKeyRefusesInASentence() throws {
        var project = HaloCommandCatalogTests.ballSelected()
        let before = project
        for (layer, property, frame) in [(ball, "x", 7), (ball, "x", 24), (floor, "x", 0), ("comp-1-layer-9", "x", 0)] {
            let why = try #require(project.keyPickRefusal(HaloKeyRef(layerID: layer, property: HaloProperty(rawValue: property) ?? .x, frame: frame)))
            #expect(throws: CatalogError.failed(id: "easing.select-key", message: why)) {
                try catalog.run("easing.select-key", params: params(layer, property, frame), on: &project)
            }
            #expect(project == before, "\(layer) \(property)@\(frame)")
        }
        #expect(project.keyPickRefusal(HaloKeyRef(layerID: ball, property: .x, frame: 7))
            == "Ball has no key on Position X at frame 7 that a later key follows, so there\u{2019}s no span to ease.")
        #expect(project.keyPickRefusal(HaloKeyRef(layerID: "comp-1-layer-9", property: .x, frame: 0))
            == "This composition has no layer comp-1-layer-9.")
    }

    @Test func aKeyOnAnotherLayerSelectsThatLayerThenPicksIt() throws {
        var project = HaloCommandCatalogTests.ballSelected()
        project.selectLayer(floor)
        _ = try catalog.run("easing.select-key", params: params(ball, "x", 0), on: &project)
        #expect(project.selectedLayerID == ball)
        #expect(project.pickedSegment?.key == HaloKeyRef(layerID: ball, property: .x, frame: 0))
        _ = try catalog.run("animation.easing", params: .object(["preset": .string("easeIn")]), on: &project)
        #expect(project.pickedSegment?.easing == .easeIn)
    }
}
