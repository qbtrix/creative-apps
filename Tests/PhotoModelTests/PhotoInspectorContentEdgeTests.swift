// PhotoInspectorContentEdgeTests.swift: adversarial checks on what Photo's
// inspector shows: a refused New Image over an open image, a second New Image
// of another size, edits reflected in the shown layer, deleting the selected
// layer, and a seeded random walk holding the invariant "No Image exactly
// when no canvas is open, otherwise the selected layer at the canvas size".
// Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoInspectorContentEdgeTests {
    @Test func refusedNewImageKeepsTheOpenImageInTheInspector() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 5, height: 7)
        let before = workspace.inspectorContent
        for (width, height) in [(0, 1), (1, 0), (-3, 4), (Int.max, Int.max)] {
            try? workspace.newCanvas(width: width, height: height)
            #expect(workspace.inspectorContent == before, "\(width)×\(height) changed the inspector")
        }
    }

    @Test func secondNewImageShowsItsOwnSizeAndBackground() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 3)
        workspace.addLayer()
        try workspace.newCanvas(width: 9, height: 2)
        guard case .layer(let layer, let width, let height) = workspace.inspectorContent else {
            Issue.record("expected a layer, got \(workspace.inspectorContent)")
            return
        }
        #expect(layer.name == "Background")
        #expect(width == 9 && height == 2)
    }

    @Test func inspectorShowsTheLayerAfterEdits() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        let id = try #require(workspace.selectedLayerID)
        workspace.setOpacity(id, percent: 40)
        workspace.setBlendMode(id, .multiply)
        workspace.renameLayer(id, to: "  Base  ")
        let shown = try #require(workspace.selectedLayer)
        #expect(workspace.inspectorContent == .layer(shown, width: 2, height: 2))
        #expect(shown.name == "Base")
    }

    @Test func deletingTheSelectedLayerNeverLeavesNoSelection() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 2, height: 2)
        for _ in 0..<4 { workspace.addLayer() }
        while let id = workspace.selectedLayerID, workspace.removeLayer(id) {
            #expect(workspace.inspectorContent != .noSelection)
            #expect(workspace.inspectorContent != .noImage)
        }
        #expect(workspace.layers.count == 1)
    }

    @Test func layerCommandsWithNoImageKeepNoImage() {
        var workspace = PhotoWorkspace()
        workspace.addLayer()
        workspace.selectLayer("layer-0")
        workspace.removeLayer("layer-0")
        workspace.setOpacity("layer-0", percent: 10)
        workspace.adjust(.exposure(1))
        #expect(workspace.inspectorContent == .noImage)
    }

    @Test(arguments: [UInt64(1), 7, 42, 2026, 0xDEAD_BEEF])
    func randomWalkKeepsTheInspectorInStep(seed: UInt64) throws {
        var workspace = PhotoWorkspace()
        var state = seed
        func roll(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
        for step in 0..<400 {
            let ids = workspace.layers.map(\.id)
            let pick = ids.isEmpty ? "layer-\(roll(5))" : ids[roll(ids.count)]
            switch roll(8) {
            case 0: try? workspace.newCanvas(width: roll(6), height: roll(6))
            case 1, 2: workspace.addLayer()
            case 3: workspace.removeLayer(pick)
            case 4: workspace.selectLayer(pick)
            case 5: workspace.selectLayer("missing-\(roll(3))")
            case 6: workspace.setOpacity(pick, percent: Double(roll(300)) - 100)
            default: workspace.toggleVisibility(pick)
            }
            let content = workspace.inspectorContent
            guard let canvas = workspace.canvas else {
                #expect(content == .noImage, "step \(step)")
                continue
            }
            let selected = try #require(workspace.selectedLayer, "step \(step): image open, nothing selected")
            #expect(content == .layer(selected, width: canvas.width, height: canvas.height), "step \(step)")
        }
    }
}
