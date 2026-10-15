// LayerPlacingContractTests.swift: what every LayerPlacing promises (#38),
// run over the fake and the live type, which share HaloKeyRules. HF-3
// (sampling equals FlareCore, exact) and HF-5 (the parent chain, 1e-9) live
// here. Also holds `keyedPair()`, the contract suites' small composition.
// Runs on Linux and macOS.
import FlareCore
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

let layerPlacings: [any LayerPlacing] = [FakeLayerPlacing(), LiveLayerPlacing()]

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

/// The first composition of fixture `name`.
private func fixture(_ name: String) throws -> HaloComposition {
    try #require(HaloFixtures.project(name)?.compositions.first)
}

/// The id of the layer called `name` in `comp`.
private func id(_ name: String, in comp: HaloComposition) throws -> String {
    try #require(comp.layers.first { $0.name == name }).id
}

@Test(arguments: layerPlacings)
func placingSamplesKeyedBallAndHoldsPastTheLastKey(placing: any LayerPlacing) throws {
    let comp = try fixture("keyed")
    let ball = try id("Ball", in: comp)
    #expect(placing.value(.x, of: ball, in: comp, at: 0) == 160)
    #expect(placing.value(.x, of: ball, in: comp, at: 6) == 360)
    #expect(placing.value(.x, of: ball, in: comp, at: 12) == 560)
    #expect(placing.value(.x, of: ball, in: comp, at: 30) == 960)
    #expect(placing.value(.opacity, of: ball, in: comp, at: 6) == 0.5)
    let floor = try #require(comp.layers.first { $0.name == "Floor" })
    let box = floor.bounds(in: comp)
    #expect(placing.value(.x, of: floor.id, in: comp, at: 6) == box.x + box.width / 2)
}

/// HF-3: every property of every layer equals FlareCore's sample of its
/// track, or the layer's default with no track. Exact.
@Test(arguments: layerPlacings)
func placingSamplingEqualsFlareCore(placing: any LayerPlacing) throws {
    for comp in [try fixture("reference"), try fixture("keyed")] {
        var mismatches = 0
        for layer in comp.layers {
            for p in HaloProperty.allCases {
                let track = layer.tracks[p.rawValue] ?? []
                for f in 0..<300 {
                    let expected = Timeline.value(of: track, at: Double(f)) ?? layer.defaultValue(p, in: comp)
                    if placing.value(p, of: layer.id, in: comp, at: f) != expected { mismatches += 1 }
                }
            }
        }
        #expect(mismatches == 0, "\(comp.name)")
    }
}

/// A null whose every transform property is held at a value: the given one,
/// else 0 (1 for scale).
private func held(_ id: String, parent: String?, _ values: [HaloProperty: Double]) -> HaloLayer {
    var layer = HaloLayer(
        id: id, name: id, kind: .null, inFrame: 0, outFrame: 60, color: HaloLayerColor(red: 0, green: 0, blue: 0))
    let defaults: [HaloProperty: Double] = [.x: 0, .y: 0, .anchorX: 0, .anchorY: 0, .rotation: 0, .scaleX: 1, .scaleY: 1]
    for (p, v) in defaults.merging(values, uniquingKeysWith: { $1 }) {
        layer.tracks[p.rawValue] = [HaloKeyframe(frame: 0, value: v)]
    }
    layer.parentID = parent
    return layer
}

private func near(_ m: HaloMatrix, _ n: HaloMatrix) -> Bool {
    zip([m.a, m.b, m.c, m.d, m.tx, m.ty], [n.a, n.b, n.c, n.d, n.tx, n.ty]).allSatisfy { abs($0 - $1) <= 1e-9 }
}

/// HF-5: translate (100, 0); rotate 90° about the anchor (50, 50); scale 2
/// about (10, 20). The child's world matrix is the three multiplied by hand.
@Test(arguments: layerPlacings)
func placingChainsThreeParentsInOrder(placing: any LayerPlacing) throws {
    let a = held("a", parent: nil, [.x: 100])
    let b = held("b", parent: "a", [.x: 50, .y: 50, .anchorX: 50, .anchorY: 50, .rotation: 90])
    let c = held("c", parent: "b", [.x: 10, .y: 20, .anchorX: 10, .anchorY: 20, .scaleX: 2, .scaleY: 2])
    let comp = HaloComposition(
        id: "k", name: "Chain", width: 400, height: 200, framesPerSecond: 24, durationFrames: 60, layers: [c, b, a])
    let world = try #require(placing.worldMatrix(of: "c", in: comp, at: 0))
    let translate = HaloMatrix(a: 1, b: 0, c: 0, d: 1, tx: 100, ty: 0)
    // T(50, 50) · R(90°) · T(−50, −50): (x, y) ↦ (100 − y, x)
    let rotate = HaloMatrix(a: 0, b: 1, c: -1, d: 0, tx: 100, ty: 0)
    // T(10, 20) · S(2, 2) · T(−10, −20): (x, y) ↦ (2x − 10, 2y − 20)
    let scale = HaloMatrix(a: 2, b: 0, c: 0, d: 2, tx: -10, ty: -20)
    #expect(near(world, translate * rotate * scale))
    #expect(!near(world, scale * rotate * translate))
    // (11, 20) → (12, 20) → (80, 12) → (180, 12)
    let p = world.apply(HaloPoint(x: 11, y: 20))
    #expect(abs(p.x - 180) <= 1e-9 && abs(p.y - 12) <= 1e-9)
}

@Test(arguments: layerPlacings)
func placingOffersNoSelfAsParent(placing: any LayerPlacing) throws {
    let comp = try fixture("parented")
    let ball = try id("Ball", in: comp)
    let candidates = placing.parentCandidates(for: ball, in: comp)
    #expect(candidates == [try id("Rig", in: comp), try id("Floor", in: comp)])
    #expect(!candidates.contains(ball))
}

/// A cycle a file can hold (n → s → n) stops the walk instead of hanging.
@Test(arguments: layerPlacings)
func placingStopsAtAParentCycle(placing: any LayerPlacing) {
    var comp = keyedPair()
    comp.layers[0].tracks["x"] = [HaloKeyframe(frame: 0, value: 300)]
    comp.layers[0].parentID = "s"
    comp.layers[1].parentID = "n"
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0) == .translation(x: 100, y: 0))
    #expect(placing.worldMatrix(of: "n", in: comp, at: 0) == .translation(x: 100, y: 0))
}

@Test func livePlacingIsAvailable() {
    #expect(LiveLayerPlacing().unavailableHelp == nil)
}
