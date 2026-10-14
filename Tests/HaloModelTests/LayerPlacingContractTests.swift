// LayerPlacingContractTests.swift: what every LayerPlacing promises (#38),
// run over each conforming type in `layerPlacings`; the live type joins by
// adding itself there. Also holds `keyedPair()`, the contract suites' small
// composition. Runs on Linux and macOS.
import HaloModel
import Testing

/// The contract tests' composition, top first: a null "n" over a 100 × 100
/// solid "s" whose x is keyed 50 at 0 and 150 at 30, both in 0..<60.
func keyedPair() -> HaloComposition {
    var solid = HaloLayer(
        id: "s", name: "Solid 1", kind: .solid, inFrame: 0, outFrame: 60,
        color: HaloLayerColor(red: 1, green: 0, blue: 0), rect: HaloLayerRect(x: 0, y: 0, width: 100, height: 100))
    solid.tracks["x"] = [HaloKeyframe(frame: 0, value: 50), HaloKeyframe(frame: 30, value: 150)]
    let null = HaloLayer(
        id: "n", name: "Null 1", kind: .null, inFrame: 0, outFrame: 60, color: HaloLayerColor(red: 0, green: 0, blue: 0))
    return HaloComposition(
        id: "c", name: "Intro", width: 400, height: 200, framesPerSecond: 24, durationFrames: 60, layers: [null, solid])
}

let layerPlacings: [any LayerPlacing] = [FakeLayerPlacing()]

@Test(arguments: layerPlacings)
func placingSamplesTracksAndFallsBackToDefaults(placing: any LayerPlacing) {
    let comp = keyedPair()
    #expect(placing.value(.x, of: "s", in: comp, at: 15) == 100)
    #expect(placing.value(.y, of: "s", in: comp, at: 15) == 50)
    #expect(placing.value(.scaleX, of: "s", in: comp, at: 15) == 1)
    #expect(placing.value(.x, of: "gone", in: comp, at: 15) == nil)
    #expect(placing.worldMatrix(of: "gone", in: comp, at: 15) == nil)
}

@Test(arguments: layerPlacings)
func placingAppliesParentsAndOffersOnlyNonFollowers(placing: any LayerPlacing) {
    var comp = keyedPair()
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0) == .identity)
    #expect(placing.parentCandidates(for: "n", in: comp) == ["s"])
    comp.layers[1].parentID = "n"
    comp.layers[0].tracks["x"] = [HaloKeyframe(frame: 0, value: 300)]
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0) == .translation(x: 100, y: 0))
    #expect(placing.parentCandidates(for: "n", in: comp).isEmpty)
    #expect(placing.parentCandidates(for: "s", in: comp) == ["n"])
}
