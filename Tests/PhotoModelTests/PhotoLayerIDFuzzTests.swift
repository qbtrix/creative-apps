// PhotoLayerIDFuzzTests.swift: adversarial checks that PhotoWorkspace layer
// ids are never reused across New Image: many New Images in a row, removed
// layers, a refused New Image, ids held across the switch, and a seeded
// random walk over every layer command. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

/// A small deterministic generator (SplitMix64) so a failing walk replays.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite struct PhotoLayerIDFuzzTests {
    @Test func everyNewImageGetsAFreshBackgroundID() throws {
        var workspace = PhotoWorkspace()
        var seen: Set<PhotoLayer.ID> = []
        for _ in 0..<50 {
            try workspace.newCanvas(width: 1, height: 1)
            #expect(workspace.layers.count == 1)
            let id = try #require(workspace.selectedLayerID)
            #expect(seen.insert(id).inserted, "\(id) came back")
        }
    }

    @Test func removedLayerIDsDoNotComeBackAfterNewImage() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        workspace.addLayer()
        workspace.addLayer()
        let removed = try #require(workspace.selectedLayerID)
        let didRemove = workspace.removeLayer(removed)
        #expect(didRemove)
        let before = Set(workspace.layers.map(\.id)).union([removed])
        try workspace.newCanvas(width: 2, height: 2)
        workspace.addLayer()
        workspace.addLayer()
        #expect(before.isDisjoint(with: workspace.layers.map(\.id)))
    }

    @Test func aRefusedNewImageChangesNothingAndLaterIDsStayFresh() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        workspace.addLayer()
        let snapshot = workspace
        #expect(throws: RasterError.self) { try workspace.newCanvas(width: -1, height: 2) }
        #expect(throws: RasterError.self) { try workspace.newCanvas(width: 2, height: 0) }
        #expect(workspace == snapshot)
        let old = Set(workspace.layers.map(\.id))
        try workspace.newCanvas(width: 2, height: 2)
        #expect(old.isDisjoint(with: workspace.layers.map(\.id)))
    }

    /// The window's closures capture a layer id; a command that lands after
    /// New Image with an old id must not touch the new canvas.
    @Test func commandsWithAnIDFromThePreviousImageAreIgnored() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        workspace.addLayer()
        let stale = workspace.layers.map(\.id)
        try workspace.newCanvas(width: 2, height: 2)
        workspace.addLayer()
        let fresh = workspace
        for id in stale {
            workspace.renameLayer(id, to: "Renamed")
            workspace.toggleVisibility(id)
            workspace.setOpacity(id, percent: 10)
            workspace.setBlendMode(id, .multiply)
            workspace.selectLayer(id)
            let didRemove = workspace.removeLayer(id)
            #expect(!didRemove)
        }
        #expect(workspace == fresh)
    }

    @Test(arguments: [UInt64(1), 42, 0xC0FFEE, 0xDEAD_BEEF, .max])
    func randomCommandWalkNeverReusesAnID(seed: UInt64) throws {
        var generator = SeededGenerator(state: seed)
        var workspace = PhotoWorkspace()
        var everSeen: Set<PhotoLayer.ID> = []
        var held: [PhotoLayer.ID] = []
        for step in 0..<2_000 {
            let before = Set(workspace.layers.map(\.id))
            switch Int.random(in: 0..<9, using: &generator) {
            case 0: try workspace.newCanvas(width: Int.random(in: 1...4, using: &generator), height: 1)
            case 1: _ = try? workspace.newCanvas(width: 0, height: 1)
            case 2, 3: workspace.addLayer()
            case 4:
                if let id = workspace.layers.randomElement(using: &generator)?.id { workspace.removeLayer(id) }
            case 5:
                let count = workspace.layers.count
                workspace.moveLayers(
                    fromOffsets: [Int.random(in: 0...max(count, 1), using: &generator)],
                    toOffset: Int.random(in: 0...count, using: &generator))
            case 6:
                if let id = held.randomElement(using: &generator) { workspace.renameLayer(id, to: "Layer 1") }
            case 7:
                if let id = held.randomElement(using: &generator) { workspace.selectLayer(id) }
            default:
                if let id = held.randomElement(using: &generator) { workspace.removeLayer(id) }
            }
            let ids = workspace.layers.map(\.id)
            #expect(Set(ids).count == ids.count, "duplicate id at step \(step), seed \(seed)")
            for id in ids where !before.contains(id) {
                #expect(!everSeen.contains(id), "\(id) reused at step \(step), seed \(seed)")
                everSeen.insert(id)
                held.append(id)
            }
            if workspace.canvas != nil {
                #expect(!ids.isEmpty)
                #expect(workspace.selectedLayer != nil, "selection lost at step \(step), seed \(seed)")
            }
        }
    }
}
