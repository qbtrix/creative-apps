// PropertyKeyingContractTests.swift: what every PropertyKeying promises
// (#38). Rows and writes run over the fake and the live type
// (`propertyKeyings`), which share HaloKeyRules; parenting runs over
// `parentKeyings`, which the live type joins once it is built. Positions are
// measured with FakeLayerPlacing, which the live keying must agree with.
// Runs on Linux and macOS.
import HaloModel
import Testing

let propertyKeyings: [any PropertyKeying] = [FakePropertyKeying(), LivePropertyKeying()]
let parentKeyings: [any PropertyKeying] = [FakePropertyKeying()]

@Test(arguments: propertyKeyings)
func rowsFollowPropertyOrderAndKeyState(keying: any PropertyKeying) {
    let comp = keyedPair()
    let rows = keying.rows(for: "s", in: comp, at: 30)
    #expect(rows.map(\.property) == HaloProperty.allCases)
    #expect(rows.first?.keyState == .keyedHere)
    #expect(keying.rows(for: "s", in: comp, at: 15).first?.keyState == .animated)
    #expect(rows.last?.keyState == .notAnimated)
    #expect(keying.rows(for: "gone", in: comp, at: 0).isEmpty)
}

/// The first composition of fixture `keyed`: Ball's x keyed at 0 and 24,
/// its opacity at 12.
private func keyedFixture() throws -> HaloComposition {
    try #require(HaloFixtures.project("keyed")?.compositions.first)
}

/// The index and id of the layer called `name` in `comp`.
private func layer(_ name: String, in comp: HaloComposition) throws -> (index: Int, id: String) {
    let i = try #require(comp.layers.firstIndex { $0.name == name })
    return (i, comp.layers[i].id)
}

/// The row for `p` of the layer called `name` at frame `f`.
private func row(
    _ p: HaloProperty, of name: String, in comp: HaloComposition, at f: Int, keying: any PropertyKeying
) throws -> HaloPropertyRow {
    let id = try layer(name, in: comp).id
    return try #require(keying.rows(for: id, in: comp, at: f).first { $0.property == p })
}

@Test(arguments: propertyKeyings)
func keyedBallRowsShowTextAndKeyState(keying: any PropertyKeying) throws {
    let comp = try keyedFixture()
    let x12 = try row(.x, of: "Ball", in: comp, at: 12, keying: keying)
    #expect(x12.text == "560.0 px" && x12.keyState == .animated)
    #expect(try row(.opacity, of: "Ball", in: comp, at: 12, keying: keying).keyState == .keyedHere)
    #expect(try row(.x, of: "Ball", in: comp, at: 6, keying: keying).keyState == .animated)
    #expect(try row(.opacity, of: "Ball", in: comp, at: 6, keying: keying).text == "50%")
    #expect(try row(.rotation, of: "Floor", in: comp, at: 12, keying: keying).keyState == .notAnimated)
    #expect(keying.rows(for: "gone", in: comp, at: 12).isEmpty)
}

@Test func liveRowsEqualTheFakesOnEveryFrame() throws {
    let comp = try keyedFixture()
    let live = LivePropertyKeying(), fake = FakePropertyKeying()
    for layer in comp.layers {
        for f in 0..<comp.durationFrames {
            #expect(live.rows(for: layer.id, in: comp, at: f) == fake.rows(for: layer.id, in: comp, at: f))
        }
    }
}

@Test func liveParentingStillRefusesUntilBuilt() {
    var comp = keyedPair()
    let before = comp
    #expect(throws: HaloEditError.notBuilt("Parenting")) {
        try LivePropertyKeying().setParent("n", of: "s", at: 0, in: &comp)
    }
    #expect(comp == before && LivePropertyKeying().unavailableHelp == nil)
}

@Test(arguments: parentKeyings)
func parentingFollowsAndRefusesCycles(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    let placing = FakeLayerPlacing()
    let before = placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50))
    try keying.setParent("n", of: "s", at: 0, in: &comp)
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50)) == before)
    #expect(placing.parentCandidates(for: "n", in: comp).isEmpty)
    #expect(throws: HaloEditError.parentCycle("Null 1")) { try keying.setParent("s", of: "n", at: 0, in: &comp) }
    try keying.setValue(300, for: .x, of: "n", at: 0, in: &comp)
    #expect(placing.worldMatrix(of: "s", in: comp, at: 0)?.apply(HaloPoint(x: 50, y: 50)).x == (before?.x ?? 0) + 100)
}

@Test(arguments: propertyKeyings)
func opacityHasOneStaticHome(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    try keying.setValue(0.5, for: .opacity, of: "s", at: 10, in: &comp)
    #expect(comp.layers[1].opacity == 0.5 && comp.layers[1].tracks["opacity"] == nil)
    try keying.toggleAnimation(.opacity, of: "s", at: 10, in: &comp)
    #expect(comp.layers[1].tracks["opacity"]?.map(\.frame) == [10, 59])
    try keying.toggleAnimation(.opacity, of: "s", at: 10, in: &comp)
    #expect(comp.layers[1].opacity == 0.5 && comp.layers[1].tracks["opacity"] == nil)
}

@Test(arguments: propertyKeyings)
func stopwatchOnKeysThePlayheadAndTheLastFrame(keying: any PropertyKeying) throws {
    var comp = keyedPair()
    try keying.toggleAnimation(.rotation, of: "s", at: 12, in: &comp)
    #expect(comp.layers[1].tracks["rotation"]?.map(\.frame) == [12, 59])
    try keying.toggleAnimation(.y, of: "s", at: 59, in: &comp)
    #expect(comp.layers[1].tracks["y"]?.map(\.frame) == [0, 59])
    #expect(keying.rows(for: "s", in: comp, at: 12).first { $0.property == .rotation }?.keyState == .keyedHere)
}

@Test(arguments: propertyKeyings)
func aValueThatIsNotANumberThrowsAndChangesNothing(keying: any PropertyKeying) {
    var comp = keyedPair()
    let before = comp
    #expect(throws: HaloEditError.notANumber(.rotation)) {
        try keying.setValue(.nan, for: .rotation, of: "s", at: 0, in: &comp)
    }
    #expect(throws: HaloEditError.notANumber(.x)) { try keying.setValue(.infinity, for: .x, of: "s", at: 15, in: &comp) }
    #expect(comp == before)
}

@Test(arguments: propertyKeyings)
func aValueKeysAnAnimatedTrackAndReplacesAStaticOne(keying: any PropertyKeying) throws {
    var comp = try keyedFixture()
    let ball = try layer("Ball", in: comp), floor = try layer("Floor", in: comp)
    try keying.setValue(1000, for: .x, of: ball.id, at: 6, in: &comp)
    #expect(comp.layers[ball.index].tracks["x"]?.map(\.frame) == [0, 6, 24])
    try keying.setValue(500, for: .x, of: floor.id, at: 30, in: &comp)
    #expect(comp.layers[floor.index].tracks["x"] == [HaloKeyframe(frame: 0, value: 500)])
    #expect(try row(.x, of: "Floor", in: comp, at: 30, keying: keying).keyState == .notAnimated)
    try keying.setValue(0.5, for: .opacity, of: floor.id, at: 30, in: &comp)
    #expect(comp.layers[floor.index].opacity == 0.5 && comp.layers[floor.index].tracks["opacity"] == nil)
    try keying.setValue(200_000, for: .x, of: floor.id, at: 0, in: &comp)
    #expect(comp.layers[floor.index].tracks["x"] == [HaloKeyframe(frame: 0, value: 100_000)])
    let before = comp
    #expect(throws: HaloEditError.notANumber(.x)) { try keying.setValue(.nan, for: .x, of: ball.id, at: 6, in: &comp) }
    #expect(throws: HaloEditError.unknownLayer("gone")) { try keying.setValue(1, for: .x, of: "gone", at: 0, in: &comp) }
    #expect(comp == before)
}

@Test(arguments: propertyKeyings)
func theStopwatchKeysTwoFramesAndGoesBackToOneValue(keying: any PropertyKeying) throws {
    let start = try keyedFixture()
    let floor = try layer("Floor", in: start)
    var comp = start
    try keying.toggleAnimation(.rotation, of: floor.id, at: 6, in: &comp)
    #expect(comp.layers[floor.index].tracks["rotation"]?.map(\.frame) == [6, 47])
    comp = start
    try keying.toggleAnimation(.rotation, of: floor.id, at: 47, in: &comp)
    #expect(comp.layers[floor.index].tracks["rotation"]?.map(\.frame) == [0, 47])
    try keying.setValue(90, for: .rotation, of: floor.id, at: 47, in: &comp)
    let at20 = try row(.rotation, of: "Floor", in: comp, at: 20, keying: keying).value
    try keying.toggleAnimation(.rotation, of: floor.id, at: 20, in: &comp)
    #expect(comp.layers[floor.index].tracks["rotation"] == [HaloKeyframe(frame: 0, value: at20)])
    #expect(try row(.rotation, of: "Floor", in: comp, at: 20, keying: keying).keyState == .notAnimated)
}

@Test(arguments: propertyKeyings)
func theDiamondAddsAndRemovesAKeyAndOneKeyLeftGoesStatic(keying: any PropertyKeying) throws {
    var comp = try keyedFixture()
    let ball = try layer("Ball", in: comp)
    try keying.toggleKey(.opacity, of: ball.id, at: 20, in: &comp)
    #expect(comp.layers[ball.index].tracks["opacity"]?.last == HaloKeyframe(frame: 20, value: 1))
    #expect(try row(.opacity, of: "Ball", in: comp, at: 20, keying: keying).keyState == .keyedHere)
    try keying.toggleKey(.opacity, of: ball.id, at: 20, in: &comp)
    #expect(comp.layers[ball.index].tracks["opacity"]?.map(\.frame) == [0, 12])
    try keying.toggleKey(.x, of: ball.id, at: 0, in: &comp)
    #expect(comp.layers[ball.index].tracks["x"] == [HaloKeyframe(frame: 0, value: 960)])
    #expect(try row(.x, of: "Ball", in: comp, at: 0, keying: keying).keyState == .notAnimated)
}
