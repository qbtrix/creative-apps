// PhotoLayersEdgeTests.swift: edge cases and a seeded fuzz run for Photo's
// layer stack: every reorder a list drag can report, long random edit runs,
// odd opacity and rename input, and blend mode titles for every mode. Runs on
// Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

private func workspace(layers extra: Int) throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 2, height: 2)
    for _ in 0..<extra { workspace.addLayer() }
    return workspace
}

/// A small deterministic generator so fuzz failures replay.
private struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The stack's invariants after any edit.
private func checkInvariants(_ workspace: PhotoWorkspace) {
    #expect(!workspace.layers.isEmpty)
    #expect(workspace.selectedLayer != nil)
    #expect(Set(workspace.layers.map(\.id)).count == workspace.layers.count)
    #expect(workspace.canRemoveLayer == (workspace.layers.count > 1))
    for layer in workspace.layers {
        #expect((0...1).contains(layer.opacity))
        #expect(!layer.name.isEmpty)
        #expect(layer.name.first?.isWhitespace == false)
        #expect(layer.name.last?.isWhitespace == false)
    }
}

@Suite struct PhotoLayersEdgeTests {
    @Test func everyDragOfFourLayersMatchesAPlainRemoveThenInsert() throws {
        let start = try workspace(layers: 3)
        let ids = start.layers.map(\.id)
        for mask in 1..<(1 << ids.count) {
            let offsets = ids.indices.filter { mask & (1 << $0) != 0 }
            for destination in 0...ids.count {
                var workspace = start
                workspace.moveLayers(fromOffsets: offsets, toOffset: destination)
                let moving = offsets.map { ids[$0] }
                var expected = ids.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
                expected.insert(contentsOf: moving, at: destination - offsets.filter { $0 < destination }.count)
                #expect(workspace.layers.map(\.id) == expected, "offsets \(offsets) to \(destination)")
                #expect(workspace.selectedLayerID == start.selectedLayerID)
            }
        }
    }

    @Test func dragWithDuplicateOrNegativeOffsetsMovesEachLayerOnce() throws {
        var workspace = try workspace(layers: 2)
        // Top first: layer-3, layer-2, layer-1.
        workspace.moveLayers(fromOffsets: [0, 0, -1], toOffset: 3)
        #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
        workspace.moveLayers(fromOffsets: [0], toOffset: -1)
        workspace.moveLayers(fromOffsets: [], toOffset: 0)
        #expect(workspace.layers.map(\.id) == ["layer-2", "layer-1", "layer-3"])
    }

    @Test func removedIDsAreNotReusedWithinACanvas() throws {
        var workspace = try workspace(layers: 1)
        let removed = workspace.removeLayer("layer-2")
        #expect(removed)
        workspace.addLayer()
        #expect(workspace.layers.map(\.id) == ["layer-3", "layer-1"])
        #expect(workspace.selectedLayer?.name == "Layer 1")
    }

    @Test func removingTheBottomSelectedLayerSelectsTheOneAbove() throws {
        var workspace = try workspace(layers: 2)
        workspace.selectLayer("layer-1")
        let removed = workspace.removeLayer("layer-1")
        #expect(removed)
        #expect(workspace.selectedLayerID == "layer-2")
    }

    @Test func removingAnUnselectedLayerKeepsTheSelection() throws {
        var workspace = try workspace(layers: 2)
        workspace.selectLayer("layer-2")
        let removed = workspace.removeLayer("layer-3")
        #expect(removed)
        #expect(workspace.selectedLayerID == "layer-2")
    }

    @Test func infiniteOpacityClamps() throws {
        var workspace = try workspace(layers: 0)
        workspace.setOpacity("layer-1", percent: -.infinity)
        #expect(workspace.layers.first?.opacity == 0)
        workspace.setOpacity("layer-1", percent: .infinity)
        #expect(workspace.layers.first?.opacity == 1)
        workspace.setOpacity("missing", percent: 10)
        #expect(workspace.layers.first?.opacity == 1)
    }

    @Test func renameTrimsTabsAndNewlinesAndIgnoresUnknownIDs() throws {
        var workspace = try workspace(layers: 0)
        workspace.renameLayer("layer-1", to: "\n\t Sky \t\n")
        workspace.renameLayer("layer-1", to: "\n\t")
        workspace.renameLayer("missing", to: "Ground")
        #expect(workspace.layers.map(\.name) == ["Sky"])
    }

    @Test func editsWithNoCanvasChangeNothing() {
        var workspace = PhotoWorkspace()
        workspace.toggleVisibility("layer-1")
        workspace.setOpacity("layer-1", percent: 10)
        workspace.setBlendMode("layer-1", .multiply)
        workspace.renameLayer("layer-1", to: "Sky")
        workspace.moveLayers(fromOffsets: [0], toOffset: 0)
        let removed = workspace.removeLayer("layer-1")
        #expect(!removed)
        #expect(workspace == PhotoWorkspace())
    }

    @Test func aRejectedNewCanvasKeepsTheOpenStack() throws {
        var workspace = try workspace(layers: 2)
        let before = workspace
        #expect(throws: RasterError.self) { try workspace.newCanvas(width: -1, height: 4) }
        #expect(workspace == before)
    }

    @Test func everyBlendModeHasADistinctTitleCaseTitle() {
        let titles = BlendMode.allCases.map(\.title)
        #expect(titles == [
            "Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Color Dodge", "Color Burn",
            "Hard Light", "Soft Light", "Difference", "Exclusion", "Hue", "Saturation", "Color", "Luminosity",
        ])
        #expect(Set(titles).count == titles.count)
    }

    @Test(arguments: [1, 7, 42, 2026])
    func randomEditRunsKeepTheStackValid(seed: UInt64) throws {
        var random = SeededRandom(state: seed)
        var workspace = try workspace(layers: 0)
        for _ in 0..<500 {
            let ids = workspace.layers.map(\.id) + ["missing"]
            let id = ids.randomElement(using: &random) ?? "missing"
            switch Int.random(in: 0..<8, using: &random) {
            case 0: workspace.addLayer()
            case 1: workspace.removeLayer(id)
            case 2: workspace.renameLayer(id, to: ["", "  ", " Sky ", "Layer 1", "\tInk\n"].randomElement(using: &random) ?? "")
            case 3: workspace.toggleVisibility(id)
            case 4: workspace.setOpacity(id, percent: [-5, 0, 37.5, 100, 250, .nan, .infinity].randomElement(using: &random) ?? 0)
            case 5: workspace.setBlendMode(id, BlendMode.allCases.randomElement(using: &random) ?? .normal)
            case 6:
                let count = workspace.layers.count
                let offsets = (0..<Int.random(in: 1...3, using: &random)).map { _ in Int.random(in: -1...count, using: &random) }
                let before = workspace.layers.map(\.id).sorted()
                workspace.moveLayers(fromOffsets: offsets, toOffset: Int.random(in: -1...(count + 1), using: &random))
                #expect(workspace.layers.map(\.id).sorted() == before)
            default: workspace.selectLayer(id)
            }
            checkInvariants(workspace)
        }
    }
}
