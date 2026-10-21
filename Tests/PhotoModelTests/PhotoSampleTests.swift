// PhotoSampleTests.swift: MJ-PE, the Model walk of Photo's eyedropper as
// SuiteKernel's SampleTarget (eyedropper PE-1). What the stubs already give
// (the help, the size option) runs now; what reads the composite waits on
// PE-6, which fills the adapter's bodies and turns those tests on. Linux.
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoSampleTests {
    /// A 64 x 64 white canvas with an empty, selected top layer: what a
    /// person sees is white, while the active layer holds nothing.
    private func whiteUnderEmptyLayer() throws -> PhotoWorkspace {
        var model = PhotoWorkspace(services: .fake)
        try model.newCanvas(width: 64, height: 64)
        model.addLayer()
        return model
    }

    @Test func sampleHelpAsksForAnImageUntilOneIsOpen() throws {
        let empty = PhotoWorkspace(services: .fake)
        #expect(empty.sampleHelp == "Open an image first.")
        #expect(try whiteUnderEmptyLayer().sampleHelp == nil)
    }

    @Test func sampleSizeIsToolStateWithNoStep() throws {
        var model = try whiteUnderEmptyLayer()
        let steps = model.historySteps
        #expect(model.sampleSize == .point)
        model.setSampleSize(.fiveByFive)
        #expect(model.sampleSize == .fiveByFive)
        #expect(model.historySteps == steps)
    }

    @Test(.disabled("waits on PE-6"))
    func sampledColorReadsTheCompositeThroughAnEmptyTopLayer() throws {
        let model = try whiteUnderEmptyLayer()
        let color = try #require(model.sampledColor(at: Point(x: 8, y: 8), size: .point))
        #expect(abs(color.r - 1) < 0.01 && abs(color.g - 1) < 0.01 && abs(color.b - 1) < 0.01)
        #expect(model.sampledColor(at: Point(x: 8, y: 8), size: .fiveByFive) == color)
    }

    @Test(.disabled("waits on PE-6"))
    func sampledColorIsNilOutsideTheImage() throws {
        let model = try whiteUnderEmptyLayer()
        #expect(model.sampledColor(at: Point(x: -5, y: -5), size: .point) == nil)
        #expect(model.sampledColor(at: Point(x: 64, y: 10), size: .fiveByFive) == nil)
    }

    @Test(.disabled("waits on PE-6"))
    func pickBrushColorSetsTheBrushAndRecordsNoStep() throws {
        var model = try whiteUnderEmptyLayer()
        let steps = model.historySteps
        try model.pickBrushColor(at: Point(x: 8, y: 8))
        #expect(model.brushOptions.red == 255 && model.brushOptions.green == 255 && model.brushOptions.blue == 255)
        #expect(model.historySteps == steps)
    }

    @Test func pickRefusesWithNoImage() {
        var empty = PhotoWorkspace(services: .fake)
        #expect(throws: PhotoRefusal("Open an image first.")) { try empty.pickBrushColor(at: Point(x: 1, y: 1)) }
    }

    @Test func aPressPicksWithTheEyedropperOrWithTheBrushAndOption() throws {
        var model = try whiteUnderEmptyLayer()
        model.selectTool(.eyedropper)
        #expect(model.pressPicksColor(modifiers: []))
        #expect(model.showsSampleLoupe)
        model.selectTool(.brush)
        #expect(!model.pressPicksColor(modifiers: []), "a plain brush press paints")
        #expect(!model.pressPicksColor(modifiers: .shift))
        #expect(model.pressPicksColor(modifiers: .option))
        #expect(!model.showsSampleLoupe, "the loupe is the Eyedropper's")
        model.selectTool(.eraser)
        #expect(!model.pressPicksColor(modifiers: .option))
    }

    @Test func nothingPicksWithNoImage() {
        var empty = PhotoWorkspace(services: .fake)
        empty.selectTool(.eyedropper)
        #expect(!empty.pressPicksColor(modifiers: []))
        #expect(!empty.showsSampleLoupe)
    }
}
