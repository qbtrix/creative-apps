// PhotoSampleTests.swift: MJ-PE, the Model walk of Photo's eyedropper as
// SuiteKernel's SampleTarget (eyedropper PE-1 stubs, PE-6 bodies). A sample
// reads the composite a person sees, not the active layer, renders only the
// square's pixels (one tile at most), centres the square on the pixel under
// the point, and picking is tool state with no undo step. RJ-P36
// (Tests/RealJobs/photo/sample-mean/) runs `color.sample` on a red and blue
// checkerboard. Linux.
import CoreRaster
import Foundation
@testable import PhotoModel
import SuiteKernel
import Synchronization
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

    /// A 20 x 10 opened image, red where x < 10 and white to its right.
    private func redLeftHalf() throws -> PhotoWorkspace {
        let rgba = (0..<10).flatMap { _ in (0..<20).flatMap { x -> [UInt8] in x < 10 ? [255, 0, 0, 255] : [255, 255, 255, 255] } }
        let png = try PhotoHeadless.codec.encode(DecodedImage(rgba8: rgba, width: 20, height: 10), as: .png, quality: 1)
        return try PhotoHeadless.open(png, name: "half.png").workspace
    }

    /// Records the pixel count of every region an adjustment layer adjusts,
    /// and leaves each as it was.
    private final class RegionLog: AdjustmentLayering {
        private let areas = Mutex<[Int]>([])
        var recorded: [Int] { areas.withLock { $0 } }
        func clear() { areas.withLock { $0 = [] } }
        var unavailableHelp: String? { nil }
        var kinds: [AdjustmentKind] { [.exposure] }
        func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double,
                      blendMode: BlendMode, mask: PixelBuffer?) throws -> PixelBuffer {
            areas.withLock { $0.append(below.width * below.height) }
            return below
        }
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

    @Test func sampledColorReadsTheCompositeThroughAnEmptyTopLayer() throws {
        let model = try whiteUnderEmptyLayer()
        let color = try #require(model.sampledColor(at: Point(x: 8, y: 8), size: .point))
        #expect(abs(color.r - 1) < 0.01 && abs(color.g - 1) < 0.01 && abs(color.b - 1) < 0.01)
        #expect(model.sampledColor(at: Point(x: 8, y: 8), size: .fiveByFive) == color)
    }

    @Test func sampledColorIsNilOutsideTheImage() throws {
        let model = try whiteUnderEmptyLayer()
        #expect(model.sampledColor(at: Point(x: -5, y: -5), size: .point) == nil)
        #expect(model.sampledColor(at: Point(x: 64, y: 10), size: .fiveByFive) == nil)
    }

    @Test func theSquareIsCentredOnThePixelUnderThePoint() throws {
        let model = try redLeftHalf()
        // Columns 9, 10 and 11: one red, two white.
        let three = try #require(model.sampledColor(at: Point(x: 10, y: 5), size: .threeByThree))
        #expect(SampleRules.byte(three.r) == 255 && SampleRules.byte(three.g) == 170 && SampleRules.byte(three.b) == 170)
        // (9.6, 5.5) lies in pixel (9, 5), the last red column.
        let point = try #require(model.sampledColor(at: Point(x: 9.6, y: 5.5), size: .point))
        #expect(SampleRules.byte(point.g) == 0)
    }

    @Test func flattensOneTile() throws {
        let log = RegionLog()
        var services = PhotoServices.fake
        services.adjustmentLayers = log
        var model = PhotoWorkspace(services: services)
        try model.newCanvas(width: 1000, height: 1000)
        model.addAdjustmentLayer(.exposure)
        log.clear()
        #expect(model.sampledColor(at: Point(x: 500, y: 500), size: .fiveByFive) != nil)
        #expect(log.recorded == [25], "only the 5 x 5 square renders, not the image")
        #expect(log.recorded.allSatisfy { $0 <= PixelBuffer.tileSize * PixelBuffer.tileSize })
    }

    @Test func pickBrushColorSetsTheBrushAndRecordsNoStep() throws {
        var model = try whiteUnderEmptyLayer()
        let steps = model.historySteps
        try model.pickBrushColor(at: Point(x: 8, y: 8))
        #expect(model.brushOptions.red == 255 && model.brushOptions.green == 255 && model.brushOptions.blue == 255)
        #expect(model.historySteps == steps)
    }

    @Test func pickReadsTheToolsSquare() throws {
        var model = try redLeftHalf()
        model.setSampleSize(.threeByThree)
        try model.pickBrushColor(at: Point(x: 10, y: 5))
        #expect(model.brushOptions.red == 255 && model.brushOptions.green == 170 && model.brushOptions.blue == 170)
    }

    @Test func pickRefusesWithNoImage() {
        var empty = PhotoWorkspace(services: .fake)
        #expect(throws: PhotoRefusal("Open an image first.")) { try empty.pickBrushColor(at: Point(x: 1, y: 1)) }
    }

    @Test func pickWithNothingThereRefusesAndKeepsTheBrush() throws {
        var model = try whiteUnderEmptyLayer()
        model.setToolOption(.color(red: 1, green: 2, blue: 3))
        #expect(throws: PhotoRefusal("Nothing to sample there.")) { try model.pickBrushColor(at: Point(x: -5, y: -5)) }
        #expect(model.brushOptions.red == 1 && model.brushOptions.green == 2 && model.brushOptions.blue == 3)
    }

    /// RJ-P36: each `color.sample` step answers the job's `samples` entry,
    /// within 1 per channel, and the job's export is its input unchanged.
    @Test func sampleMeanJobReadsTheCheckerboardMean() throws {
        struct Job: Decodable { var steps: [CommandEnvelope]; var samples: [JSONValue] }
        let folder = PhotoJob.root.appendingPathComponent("sample-mean")
        let job = try JSONDecoder().decode(Job.self, from: Data(contentsOf: folder.appendingPathComponent("sample-mean.jobs.json")))
        let input = try Data(contentsOf: folder.appendingPathComponent("input/checker-red-blue.png"))
        var doc = try PhotoHeadless.open(input, name: "checker-red-blue.png")
        #expect(job.steps.count == job.samples.count)
        for (step, want) in zip(job.steps, job.samples) {
            let got = try PhotoHeadless.catalog.run(step, on: &doc).result
            guard let wanted = Self.channels(want) else { #expect(got == want); continue }
            let read = try #require(Self.channels(got), "\(got)")
            #expect(zip(read, wanted).allSatisfy { abs($0 - $1) <= 1 }, "\(got) is not \(want)")
        }
        #expect(try PhotoJob.check("sample-mean") == [])
    }

    /// A `color.sample` result's r, g, b and a; nil when its colour is null.
    private static func channels(_ result: JSONValue) -> [Double]? {
        guard case .object(let fields) = result, case .object(let color)? = fields["color"] else { return nil }
        return ["r", "g", "b", "a"].map { key -> Double in
            guard case .number(let value)? = color[key] else { return -1 }
            return value
        }
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
