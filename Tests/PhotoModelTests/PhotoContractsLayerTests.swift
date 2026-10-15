// PhotoContractsLayerTests.swift: the selection, layer and output contracts
// (blueprint 5.1) keep their defaults, titles and modifier mappings. Runs on
// Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoContractsLayerTests {
    @Test func shiftAddsOptionSubtractsNoneReplaces() {
        #expect(SelectionCombine([.shift]) == .add)
        #expect(SelectionCombine([.option]) == .subtract)
        #expect(SelectionCombine([]) == .replace)
        #expect(SelectionCombine([.shift, .option]) == .add)
    }

    @Test func sampleSizesHaveTheirTitlesAndWidths() {
        #expect(SampleSize.allCases.map(\.title) == ["Point", "3 × 3", "5 × 5"])
        #expect(SampleSize.allCases.map(\.rawValue) == [1, 3, 5])
    }

    @Test func identityTransformIsAllOnesAndZeros() {
        let identity = LayerTransform.identity
        #expect(identity.scaleX == 1 && identity.scaleY == 1)
        #expect(identity.degrees == 0 && identity.dx == 0 && identity.dy == 0)
        #expect(LayerTransform() == identity)
    }

    @Test func exportOptionsDefaultToFullSizePNG() {
        let options = ExportOptions()
        #expect(options.format == .png)
        #expect(options.quality == 0.9)
        #expect(options.size == .percent(100))
    }

    @Test func selectionOptionsDefaultToASharpRectangle() {
        let options = SelectionOptions()
        #expect(options.shape == .rectangle && options.feather == 0)
        #expect(SelectionShapeKind.allCases == [.rectangle, .ellipse, .lasso])
    }

    @Test func transformHandlesAreTheEightSidesInsideAndRotate() {
        #expect(TransformHandle.allCases.count == 10)
        #expect(TransformHandle.allCases.contains(.inside) && TransformHandle.allCases.contains(.rotate))
    }
}
