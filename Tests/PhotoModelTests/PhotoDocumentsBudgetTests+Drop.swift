// PhotoDocumentsBudgetTests+Drop.swift: one dropped photo placed as a layer (file-flow, quality gate #5833), timed as
// the window runs it: `perform([.place])` reads the file from disk with Photo's real codec, fits it inside the canvas
// and adds the layer in one "Place" step. In a release build (`swift test -c release -Xswiftc -enable-testing
// --filter PhotoDocumentsBudgetTests`) a 6000 x 4000 photo (24 MP, noisy as a camera picture) drops on the `large`
// fixture (4000 x 3000) and must land within `dropBudget`, fitted to 4000 x 2667. Debug runs a 600 x 400 photo on a
// 400 x 300 image and only reports. It sits in PhotoDocumentsBudgetTests, which `Tests/perf-suites.txt` keeps out
// of the gate.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import Testing

/// One drop's bound for a 24 MP photo on the `large` fixture in release: the whole-document pass bound.
private let dropBudget = Duration.seconds(2)
#if DEBUG
private let dropSize = (width: 600, height: 400), dropCanvas = (width: 400, height: 300), gateDrop = false
#else
private let dropSize = (width: 6000, height: 4000), dropCanvas = (width: 4000, height: 3000), gateDrop = true
#endif

extension PhotoDocumentsBudgetTests {
    @Test func dropAPhotoOntoAnImage() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoDropBudget-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("Camera.png").path
        try noisyPNG(dropSize.width, dropSize.height).write(to: URL(fileURLWithPath: path))
        var workspace = PhotoWorkspace(services: .fake)
        workspace.start(with: try TiledPixels(width: dropCanvas.width, height: dropCanvas.height,
                                              fill: RGBA(r: 1, g: 1, b: 1, a: 1)), name: "base.png")
        let cost = try ContinuousClock().measure { try workspace.perform([.place(path: path)]) }
        let layer = try #require(workspace.selectedLayer)
        let fitted = (dropCanvas.width, Int((Double(dropSize.height * dropCanvas.width) / Double(dropSize.width)).rounded()))
        #expect(layer.name == "Camera")
        #expect(workspace.pixels[layer.id].map { ($0.width, $0.height) } ?? (0, 0) == fitted, "not fitted inside the image")
        print("PhotoBudget drop (read, fit, place) \(dropSize.width)x\(dropSize.height) onto "
              + "\(dropCanvas.width)x\(dropCanvas.height) \(cost / .milliseconds(1)) ms, bound "
              + "\(dropBudget / .milliseconds(1)) ms (1 event, \(gateDrop ? "gated" : "report only"))")
        if gateDrop { #expect(cost <= dropBudget, "drop: \(cost)") }
    }

    /// A noisy diagonal gradient PNG, as dense as a camera picture, from a fixed seed.
    private func noisyPNG(_ width: Int, _ height: Int) throws -> Data {
        var rgba = [UInt8](repeating: 255, count: width * height * 4), seed: UInt32 = 0x2545_F491
        for y in 0..<height {
            for x in 0..<width {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Int(seed >> 27), at = (y * width + x) * 4
                rgba[at] = UInt8(truncatingIfNeeded: x * 200 / width + noise)
                rgba[at + 1] = UInt8(truncatingIfNeeded: y * 180 / height + noise)
                rgba[at + 2] = UInt8(truncatingIfNeeded: 220 - (x + y) * 100 / (width + height) + noise)
            }
        }
        return try PhotoHeadless.codec.encode(DecodedImage(rgba8: rgba, width: width, height: height), as: .png, quality: 1)
    }
}
