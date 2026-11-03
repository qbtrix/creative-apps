// HaloDrawListLookupTests.swift: a frame's draw list places each layer it
// already holds, never by looking its id up again. An id lookup is a scan of
// every layer, so one per layer made huge's 2,000-layer draw list quadratic;
// the viewer drag's lift builds one at the press, and the real Halo froze
// there (#5950). Runs on Linux and macOS.
import HaloModel
import Testing

/// Counts the id-keyed placing calls and answers every call through the live placing.
private final class LookupSpy: LayerPlacing, @unchecked Sendable {
    let live = LiveLayerPlacing()
    var lookups = 0
    var unavailableHelp: String? { nil }
    func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? {
        lookups += 1
        return live.value(property, of: layerID, in: composition, at: frame)
    }
    func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        lookups += 1
        return live.worldMatrix(of: layerID, in: composition, at: frame)
    }
    func value(_ property: HaloProperty, of layer: HaloLayer, in composition: HaloComposition, at frame: Int) -> Double? {
        live.value(property, of: layer, in: composition, at: frame)
    }
    func worldMatrix(of layer: HaloLayer, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        live.worldMatrix(of: layer, in: composition, at: frame)
    }
    func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        live.parentCandidates(for: layerID, in: composition)
    }
}

struct HaloDrawListLookupTests {
    @Test func aDrawListLooksUpNoLayerByID() throws {
        for name in ["reference", "parented", "crowd"] {
            let comp = try #require(HaloFixtures.project(name)?.compositions.first, "no \(name)")
            let spy = LookupSpy()
            let list = LiveFrameDrawing(placing: spy).drawList(comp, at: 12)
            #expect(spy.lookups == 0, "\(name): \(spy.lookups) id lookups for \(list.items.count) layers")
            #expect(list == LiveFrameDrawing().drawList(comp, at: 12), "\(name): the list changed")
        }
    }

    @Test func aHeldLayerPlacesAsItsID() throws {
        let live = LiveLayerPlacing()
        for name in ["parented", "keyed", "reference"] {
            let comp = try #require(HaloFixtures.project(name)?.compositions.first, "no \(name)")
            for layer in comp.layers {
                #expect(live.worldMatrix(of: layer, in: comp, at: 7) == live.worldMatrix(of: layer.id, in: comp, at: 7))
                #expect(live.value(.opacity, of: layer, in: comp, at: 7) == live.value(.opacity, of: layer.id, in: comp, at: 7))
            }
        }
    }

    @Test func aHeldFollowerKeepsItsParentsPlace() throws {
        var comp = try #require(HaloFixtures.project("parented")?.compositions.first)
        let rig = try #require(comp.layers.first { $0.kind == .null })
        let i = try #require(comp.layers.firstIndex { $0.kind != .null })
        comp.layers[i].parentID = rig.id
        var alone = comp.layers[i]
        alone.parentID = nil
        let live = LiveLayerPlacing()
        #expect(live.worldMatrix(of: comp.layers[i], in: comp, at: 40) != live.worldMatrix(of: alone, in: comp, at: 40))
    }
}
