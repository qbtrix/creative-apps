// PhotoExportBudgetTests.swift: export-pack's real-size export cost (quality
// gate #5834, bugs 5 and 9; packet row "Export cost", photo/features/
// export-pack.md). The whole headless export the CLI runs
// (`PhotoHeadless.export`: render, resample, encode), timed once per case on
// photo-like pixels at the audit's sizes: 6000 x 4000 at 1x and at long edge
// 2048, a 4:5 crop of it at 1080 x 1350 (RJ-P01), and 4032 x 3024 at Pixels
// 1080 x 810 and at scale 2 (8064 x 6048 PNG). Gated in a release build,
// reported in debug. The cases live in PhotoBudgetTests, so the gate skips
// them with its perf list (Tests/perf-suites.txt) and perf-nightly runs them.
import Foundation
import PhotoModel
import SuiteKernel
import Testing

#if DEBUG
private let exportGated = false
#else
private let exportGated = true
#endif

extension PhotoBudgetTests {
    /// One audit case: the image size, the export format and options, and its budget.
    struct ExportCase: CustomTestStringConvertible, Sendable {
        let name: String, width: Int, height: Int, format: String, options: String, crop45: Bool, budget: Duration
        var testDescription: String { name }
    }

    static let exportCases: [ExportCase] = [
        ExportCase(name: "6000x4000 jpeg 1x", width: 6000, height: 4000, format: "jpeg", options: "{}", crop45: false, budget: .seconds(3)),
        ExportCase(name: "6000x4000 jpeg longEdge 2048", width: 6000, height: 4000, format: "jpeg",
                   options: #"{"size":{"longEdge":2048}}"#, crop45: false, budget: .milliseconds(1500)),
        ExportCase(name: "6000x4000 4:5 crop jpeg 1080x1350", width: 6000, height: 4000, format: "jpeg",
                   options: #"{"size":{"pixels":[1080,1350]},"quality":0.85}"#, crop45: true, budget: .milliseconds(1500)),
        ExportCase(name: "4032x3024 jpeg 1080x810", width: 4032, height: 3024, format: "jpeg",
                   options: #"{"size":{"pixels":[1080,810]}}"#, crop45: false, budget: .milliseconds(1500)),
        ExportCase(name: "4032x3024 png scale 2", width: 4032, height: 3024, format: "png",
                   options: #"{"size":{"scale":2}}"#, crop45: false, budget: .seconds(6)),
    ]

    @Test(arguments: PhotoBudgetTests.exportCases)
    func realSizeExport(_ c: ExportCase) throws {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: Self.photoLike(c.width, c.height), width: c.width, height: c.height, name: "real.jpg")
        if c.crop45 {
            let width = c.height * 4 / 5, left = (c.width - width) / 2
            stroke(&workspace, .crop, from: point(Double(left), 0), to: point(Double(left + width), Double(c.height)))
            workspace.applyCrop()
        }
        let options = try JSONValue(json: Data(c.options.utf8))
        var files: [ExportedFile] = []
        let cost = try ContinuousClock().measure { files = try PhotoHeadless(workspace: workspace).export(c.format, options: options) }
        let ms = (cost / .milliseconds(1)).rounded()
        print("PhotoBudget export \(c.name): \(ms) ms, budget \(c.budget) (\(exportGated ? "gated" : "report only"))")
        #expect(files.count == 1 && files.first?.data.isEmpty == false)
        if exportGated { #expect(cost <= c.budget, "export \(c.name): \(ms) ms over \(c.budget)") }
    }

    /// Straight sRGB bytes with a photo's texture: two gradients and per-pixel noise, so the encoders do real work.
    static func photoLike(_ width: Int, _ height: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        var seed: UInt32 = 12_345
        for y in 0..<height {
            for x in 0..<width {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Int(seed >> 26), i = (y * width + x) * 4
                bytes[i] = UInt8((x * 255 / width + noise) & 255)
                bytes[i + 1] = UInt8((y * 255 / height + noise) & 255)
                bytes[i + 2] = UInt8((x ^ y) & 255)
            }
        }
        return bytes
    }
}
