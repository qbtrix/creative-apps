// HaloFixturesTests.swift: each fixture matches its row in blueprint
// section 2, so the journeys that launch on it assert what is there. The
// only test that encodes `huge`. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HaloModel
import Testing

/// Compositions, layers and keys in `state`.
func fixtureCounts(_ state: HaloDocumentState) -> (comps: Int, layers: Int, keys: Int) {
    let layers = state.compositions.flatMap(\.layers)
    return (state.compositions.count, layers.count, layers.reduce(0) { $0 + $1.tracks.values.reduce(0) { $0 + $1.count } })
}

@Test(arguments: [
    ("empty", 1, 0, 0), ("three-layers", 1, 4, 0), ("keyed", 1, 2, 4), ("parented", 1, 3, 6),
    ("two-comps", 2, 6, 4), ("reference", 1, 50, 4_000), ("crowd", 1, 300, 5_000),
])
func fixtureHasItsCounts(name: String, comps: Int, layers: Int, keys: Int) throws {
    let state = try #require(HaloFixtures.project(name))
    #expect(fixtureCounts(state) == (comps, layers, keys))
    #expect(state.selectedCompositionID == state.compositions.first?.id)
}

@Test func everyNameResolvesAndAnUnknownOneDoesNot() {
    #expect(HaloFixtures.names.count == 8)
    #expect(HaloFixtures.names.allSatisfy { HaloFixtures.project($0) != nil })
    #expect(HaloFixtures.project("nope") == nil)
}

@Test func threeLayersReadsAsItsJourneysExpect() throws {
    let comp = try #require(HaloFixtures.project("three-layers")?.compositions.first)
    #expect((comp.name, comp.width, comp.height, comp.framesPerSecond, comp.durationFrames) == ("Intro", 1920, 1080, 24, 72))
    #expect(comp.layers.map(\.name) == ["Title", "Badge", "Background", "Rig"])
    #expect(comp.layers.map(\.kind) == [.text, .shape, .solid, .null])
    let title = try #require(comp.layers.first)
    #expect(title.text?.string == "Hello Halo" && (title.inFrame, title.outFrame) == (24, 72))
}

@Test func keyedBallMovesAndFades() throws {
    let comp = try #require(HaloFixtures.project("keyed")?.compositions.first)
    #expect((comp.name, comp.framesPerSecond, comp.durationFrames) == ("Bounce", 24, 48))
    #expect(comp.layers.map(\.name) == ["Ball", "Floor"])
    let placing = FakeLayerPlacing(), ball = comp.layers[0].id
    #expect(placing.value(.x, of: ball, in: comp, at: 0) == 160 && placing.value(.x, of: ball, in: comp, at: 24) == 960)
    #expect(placing.value(.opacity, of: ball, in: comp, at: 0) == 0 && placing.value(.opacity, of: ball, in: comp, at: 12) == 1)
    #expect(comp.layers[1].tracks.isEmpty)
}

@Test func parentedAddsAFreeRigAndTwoCompsPairsIntroAndOutro() throws {
    let parented = try #require(HaloFixtures.project("parented")?.compositions.first)
    let rig = try #require(parented.layers.first { $0.name == "Rig" })
    #expect(rig.kind == .null && rig.tracks["x"]?.map(\.frame) == [0, 47] && rig.tracks["x"]?.map(\.value) == [960, 1160])
    #expect(parented.layers.allSatisfy { $0.parentID == nil })
    let two = try #require(HaloFixtures.project("two-comps"))
    #expect(two.compositions.map(\.name) == ["Intro", "Outro"])
    #expect(two.compositions.last?.layers.first?.tracks["x"]?.count == 2)
}

@Test(arguments: HaloFixtures.names.filter { $0 != "huge" })
func fixtureRoundTripsAndKeepsIdsFresh(name: String) throws {
    let state = try #require(HaloFixtures.project(name))
    let files = FakeProjectFiles()
    #expect(try files.decode(files.encode(state)) == state)
    let ids = state.compositions.flatMap(\.layers).map(\.id) + state.compositions.map(\.id)
    #expect(Set(ids).count == ids.count)
    let layerNumbers = state.compositions.flatMap(\.layers).compactMap { Int($0.id.split(separator: "-").last ?? "") }
    #expect(layerNumbers.allSatisfy { $0 < state.nextLayerNumber })
    #expect(state.nextCompositionNumber == state.compositions.count + 1)
}

@Test func hugeStaysUnderThreeQuartersOfTheFileLimitWithWholeValues() throws {
    let state = try #require(HaloFixtures.project("huge"))
    let layers = state.compositions.flatMap(\.layers)
    #expect(layers.count == 2_000)
    let tracks = layers.flatMap(\.tracks.values)
    #expect(tracks.count == 2_000 * HaloProperty.allCases.count)
    #expect(tracks.allSatisfy { $0.count == 120 / HaloFixtures.hugeKeySpacing })
    #expect(tracks.allSatisfy { $0.allSatisfy { $0.value == $0.value.rounded() } })
    let bytes = try FakeProjectFiles().encode(state).count
    #expect(bytes > 16 * 1024 * 1024, "huge encodes to \(bytes) bytes")
    #expect(bytes <= FakeProjectFiles.maxBytes / 4 * 3, "huge encodes to \(bytes) bytes")
}
