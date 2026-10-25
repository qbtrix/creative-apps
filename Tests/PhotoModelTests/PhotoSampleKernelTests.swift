// PhotoSampleKernelTests.swift: MJ-EP (suiteui/adopt-kernel-eyedropper-photo,
// EP-1 wrote it disabled, EP-2 turned it on). An Eyedropper click and
// `color.sample` read one sampler, SuiteKernel's `SampleRules.mean`: for each
// sample size, a click at the centre, at a corner and at the far corner gives
// the kernel's colour, the same as `color.sample`, and the square skips the
// pixels off the image instead of reading them as black. One pixel past the
// edge a click changes nothing. RJ-X49 (Tests/RealJobs/photo/sample-edge/)
// samples the corner and the centre by command. Linux.
import CoreRaster
import Foundation
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoSampleKernelTests {
    /// The side of the checkerboard and of one of its cells.
    static let side = 16, cell = 4

    /// RJ-X49's fixture in bytes: 4 x 4 cells of pure red and pure blue, red where the cell's column + row is
    /// even, so the top-left cell is red.
    static let checker: [UInt8] = (0..<side).flatMap { y in
        (0..<side).flatMap { x -> [UInt8] in (x / cell + y / cell) % 2 == 0 ? [255, 0, 0, 255] : [0, 0, 255, 255] }
    }

    /// The checkerboard opened on the fake services, the Eyedropper picked.
    private func opened() throws -> PhotoWorkspace {
        var model = PhotoWorkspace(services: .fake)
        try model.open(rgba8: Self.checker, width: Self.side, height: Self.side, name: "checker-red-blue.png")
        model.selectTool(.eyedropper)
        return model
    }

    /// The kernel's mean of the `size` square at (x, y) over the checkerboard, as 0...255 channels.
    private func kernel(_ x: Int, _ y: Int, _ size: SampleSize) -> [Int]? {
        let mean = SampleRules.mean(x: x, y: y, size: size) { px, py in
            guard (0..<Self.side).contains(px), (0..<Self.side).contains(py) else { return nil }
            let at = (py * Self.side + px) * 4
            return SampleRGBA(r: Self.checker[at], g: Self.checker[at + 1], b: Self.checker[at + 2], a: Self.checker[at + 3])
        }
        return mean.map { [SampleRules.byte($0.r), SampleRules.byte($0.g), SampleRules.byte($0.b)] }
    }

    /// The brush colour after one Eyedropper click at (x, y) with the tool's square set to `size`.
    private func click(_ model: inout PhotoWorkspace, _ x: Double, _ y: Double, _ size: SampleSize) -> [Int] {
        model.setSampleSize(size)
        model.drag(from: Mask.Point(x: x, y: y), to: Mask.Point(x: x, y: y), modifiers: [])
        model.endDrag()
        return [Int(model.brushOptions.red), Int(model.brushOptions.green), Int(model.brushOptions.blue)]
    }

    /// `color.sample`'s r, g and b at (x, y) for `size`; nil when its colour is null.
    private func command(_ model: PhotoWorkspace, _ x: Double, _ y: Double, _ size: SampleSize) throws -> [Int]? {
        var doc = PhotoHeadless(workspace: model)
        let params = JSONValue.object(["x": .number(x), "y": .number(y), "size": .number(Double(size.rawValue))])
        let result = try PhotoHeadless.catalog.run("color.sample", params: params, on: &doc).result
        guard case .object(let fields) = result, case .object(let color)? = fields["color"] else { return nil }
        return ["r", "g", "b"].map { key in
            guard case .number(let value)? = color[key] else { return -1 }
            return Int(value)
        }
    }

    @Test
    func clickAndCommandReadTheKernelMeanAtTheCentreAndTheCorners() throws {
        for size in SampleSize.allCases {
            for (x, y) in [(8, 8), (0, 0), (Self.side - 1, Self.side - 1)] {
                var model = try opened()
                let want = try #require(kernel(x, y, size))
                #expect(click(&model, Double(x), Double(y), size) == want, "click at (\(x), \(y)), \(size)")
                #expect(try command(model, Double(x), Double(y), size) == want, "color.sample at (\(x), \(y)), \(size)")
            }
        }
    }

    @Test
    func edgeSkipsOffImage() throws {
        var model = try opened()
        // The corner's 5 x 5 square holds 9 in-image pixels, all red: off-image pixels read as black would darken it.
        #expect(click(&model, 0, 0, .fiveByFive) == [255, 0, 0])
        #expect(try command(model, 0, 0, .fiveByFive) == [255, 0, 0])
        #expect(click(&model, 15.5, 0.5, .fiveByFive) == [0, 0, 255], "the top-right cell is blue")
    }

    @Test
    func sizeHonoured() throws {
        var model = try opened()
        // (8, 8) is red; its 5 x 5 square is 13 red and 12 blue, its 3 x 3 square 5 red and 4 blue.
        #expect(click(&model, 8, 8, .point) == [255, 0, 0])
        #expect(click(&model, 8, 8, .fiveByFive) == [133, 0, 122])
        #expect(click(&model, 8, 8, .threeByThree) == kernel(8, 8, .threeByThree))
        #expect(model.sampleSize == .threeByThree)
    }

    @Test
    func onePixelPastTheEdgeChangesNothing() throws {
        for size in SampleSize.allCases {
            for (x, y) in [(-1.0, 8.0), (8.0, -1.0), (Double(Self.side), 8.0), (8.0, Double(Self.side))] {
                var model = try opened()
                model.setToolOption(.color(red: 1, green: 2, blue: 3))
                let steps = model.historySteps
                #expect(click(&model, x, y, size) == [1, 2, 3], "click at (\(x), \(y)), \(size)")
                #expect(try command(model, x, y, size) == nil, "color.sample at (\(x), \(y)), \(size)")
                #expect(model.historySteps == steps)
            }
        }
    }

    /// RJ-X49: each step answers the job's `samples` entry, the colours exactly, and the export is the input.
    @Test
    func sampleEdgeJobReadsTheKernelMean() throws {
        struct Job: Decodable { var steps: [CommandEnvelope]; var samples: [JSONValue] }
        let folder = PhotoJob.root.appendingPathComponent("sample-edge")
        let job = try JSONDecoder().decode(Job.self, from: Data(contentsOf: folder.appendingPathComponent("sample-edge.jobs.json")))
        let input = try Data(contentsOf: folder.appendingPathComponent("input/checker-red-blue.png"))
        #expect(try PNG.read(input).rgba8() == Self.checker, "the fixture is the checkerboard these tests read")
        var doc = try PhotoHeadless.open(input, name: "checker-red-blue.png")
        #expect(job.steps.count == job.samples.count)
        for (step, want) in zip(job.steps, job.samples) {
            #expect(try PhotoHeadless.catalog.run(step, on: &doc).result == want, "\(step.id) \(step.params)")
        }
        let corner = try #require(kernel(0, 0, .fiveByFive)), centre = try #require(kernel(8, 8, .fiveByFive))
        #expect(corner == [255, 0, 0] && centre == [133, 0, 122])
        #expect(try PhotoJob.check("sample-edge") == [])
    }
}
