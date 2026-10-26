// PhotoExportPackTests.swift: Photo's export on the suite's export options
// (export-pack, MJ-PX): exact pixels on a cropped image, a refused shape, the
// long edge, the agent's JSON options giving the sheet's pixels, a framed crop
// cut before the resample, and RJ-P01's plan half (Tests/RealJobs/photo/
// instagram: its image.crop step waits on #3692, so the crop runs through the
// workspace here). Written by PX-1, turned on by PX-3. Linux-safe.
//
// The export resamples with Lanczos in a debug build, which costs seconds per
// megapixel, so every fixture here is small: the rules are the same at any
// size. Only RJ-P01's check exports at the job's real 1080 × 1350, and it is
// listed in Tests/heavy-suites.txt so it runs outside the parallel pass.
import Foundation
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoExportPackTests {
    /// A 3:2 image cut to 4:5 in the middle: 120 × 80 to 64 × 80.
    private func croppedToFourByFive() throws -> PhotoWorkspace {
        var workspace = try whiteImage(120, 80)
        stroke(&workspace, .crop, from: point(28, 0), to: point(92, 80))
        workspace.applyCrop()
        return workspace
    }

    @Test func aFourByFiveCropAtPixelsWritesExactlyThatSize() throws {
        let workspace = try croppedToFourByFive()
        let options = SuiteExportOptions(format: "jpeg", size: .pixels(width: 108, height: 135), quality: 0.85)
        let image = try workspace.exportPixels(options)
        #expect((image.width, image.height) == (108, 135))
    }

    @Test func aThreeByTwoImageAtFourByFivePixelsIsRefused() throws {
        let workspace = try whiteImage(1200, 800)
        let options = SuiteExportOptions(format: "jpeg", size: .pixels(width: 1080, height: 1350))
        #expect(throws: ExportOptionRefusal.self) { try workspace.exportPixels(options) }
    }

    @Test func theLongEdgeKeepsTheShape() throws {
        let workspace = try whiteImage(300, 200)
        let image = try workspace.exportPixels(SuiteExportOptions(format: "heic", size: .longEdge(128)))
        #expect((image.width, image.height) == (128, 85))
    }

    @Test func theAgentsJSONOptionsGiveTheSheetsPixels() throws {
        let workspace = try croppedToFourByFive()
        let json = JSONValue.object([
            "format": .string("jpeg"), "size": .object(["pixels": .array([.number(108), .number(135)])]),
            "quality": .number(0.85),
        ])
        let fromJSON = try SuiteExportOptions(json: json, defaults: workspace.exportOptionsDefault())
        let fromSheet = SuiteExportOptions(format: "jpeg", size: .pixels(width: 108, height: 135), quality: 0.85)
        #expect(fromJSON == fromSheet)
        #expect(try workspace.exportPixels(fromJSON) == workspace.exportPixels(fromSheet))
        let headless = try #require(PhotoHeadless(workspace: workspace).export("png", options: json).first)
        let decoded = try PhotoHeadless.codec.decode(headless.data, longestSide: nil)
        #expect(try decoded == workspace.exportPixels(SuiteExportOptions(format: "png", size: fromSheet.size)))
        #expect(throws: (any Error).self) { try PhotoHeadless(workspace: whiteImage(12, 8)).export("png", options: json) }
    }

    /// RJ-P01's job folder: its script, and its 300 × 200 landscape with a red marker at (100, 100).
    struct Job: Decodable {
        struct Step: Decodable { var params: Crop }
        struct Crop: Decodable { var x, y, width, height: Int }
        struct Output: Decodable { var format: String; var options: JSONValue }
        var pending: String?
        var steps: [Step]
        var output: Output
        static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/photo/instagram")
        static func load() throws -> Job {
            try JSONDecoder().decode(Job.self, from: Data(contentsOf: folder.appendingPathComponent("instagram.jobs.json")))
        }
        static func landscape() throws -> PhotoWorkspace {
            try PhotoHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/landscape.png")), name: "landscape.png")
                .workspace
        }
    }

    /// The centre of the red pixels, weighted by how red each is, in pixel units.
    private func redCentre(_ image: DecodedImage) -> (x: Double, y: Double) {
        var sum = (x: 0.0, y: 0.0, w: 0.0)
        for y in 0..<image.height {
            for x in 0..<image.width {
                let at = (y * image.width + x) * 4
                guard image.rgba8.indices.contains(at + 1) else { continue }
                let w = Double(255 - Int(image.rgba8[at + 1]))
                sum = (sum.x + w * (Double(x) + 0.5), sum.y + w * (Double(y) + 0.5), sum.w + w)
            }
        }
        return sum.w > 0 ? (sum.x / sum.w, sum.y / sum.w) : (-1, -1)
    }

    @Test func aFramedCropIsCutBeforeTheResample() throws {
        var workspace = try Job.landscape()
        stroke(&workspace, .crop, from: point(20, 0), to: point(180, 200))
        let image = try workspace.exportPixels(SuiteExportOptions(format: "png", size: .pixels(width: 216, height: 270)))
        #expect((image.width, image.height) == (216, 270))
        let centre = redCentre(image)
        #expect(abs(centre.x - 108) <= 1 && abs(centre.y - 135) <= 1, "the marker is at \(centre)")
    }

    @Test func rjP01sPlanHalfCropsToFourByFiveAndKeepsTheSubjectFramed() throws {
        let job = try Job.load()
        #expect(job.pending == "#3692")
        let crop = try #require(job.steps.first?.params)
        var workspace = try Job.landscape()
        stroke(&workspace, .crop, from: point(Double(crop.x), Double(crop.y)),
               to: point(Double(crop.x + crop.width), Double(crop.y + crop.height)))
        workspace.applyCrop()
        let file = try #require(PhotoHeadless(workspace: workspace).export(job.output.format, options: job.output.options).first)
        let image = try PhotoHeadless.codec.decode(file.data, longestSide: nil)
        #expect((image.width, image.height) == (1080, 1350))
        let centre = redCentre(image)
        #expect(abs(centre.x - 540) <= 2 && abs(centre.y - 675) <= 2, "the marker is at \(centre)")
    }
}
