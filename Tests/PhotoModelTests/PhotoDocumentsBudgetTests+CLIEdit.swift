// PhotoDocumentsBudgetTests+CLIEdit.swift: one afterglow CLI edit on a photo, timed as the CLI runs it on the live
// services and Photo's real image codec: open the saved .ora, run `layer.new`, save the .ora again (each save
// writes the layer and the merged image as PNGs). In a release build (`swift test -c release -Xswiftc
// -enable-testing --filter PhotoDocumentsBudgetTests`) the photo is 3000 x 2000 of noisy gradient, as dense as a
// camera picture, and the edit must finish within `editBudget`. Debug converts every pixel slowly, so it runs a
// 300 x 200 photo and only reports. It sits in PhotoDocumentsBudgetTests, a suite `Tests/perf-suites.txt` keeps
// out of the gate.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// One CLI edit's bound on the 3000 x 2000 photo in release.
private let editBudget = Duration.milliseconds(1500)
#if DEBUG
private let photoSize = (width: 300, height: 200), gateEdit = false
#else
private let photoSize = (width: 3000, height: 2000), gateEdit = true
#endif

extension PhotoDocumentsBudgetTests {
    @Test func cliEditOnAPhoto() throws {
        let saved = try PhotoHeadless.open(try photo(), name: "photo.png").save()
        let clock = ContinuousClock()
        var out = Data()
        let cost = try clock.measure {
            var document = try PhotoHeadless.open(saved, name: "photo.ora")
            _ = try PhotoHeadless.catalog.run("layer.new", params: .object([:]), on: &document)
            out = try document.save()
        }
        let reopened = try PhotoHeadless.open(out, name: "photo.ora")
        #expect(reopened.workspace.layers.count == 2)
        print("PhotoBudget CLI edit (open, layer.new, save) on \(photoSize.width)x\(photoSize.height) "
              + "\(cost / .milliseconds(1)) ms, bound \(editBudget / .milliseconds(1)) ms "
              + "(1 event, \(gateEdit ? "gated" : "report only"))")
        if gateEdit { #expect(cost <= editBudget, "CLI edit: \(cost)") }
    }

    /// A PNG as dense as a camera picture: a diagonal gradient with per-pixel noise from a fixed seed.
    private func photo() throws -> Data {
        let (width, height) = photoSize
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
