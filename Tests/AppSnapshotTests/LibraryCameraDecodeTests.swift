// LibraryCameraDecodeTests.swift: ImageIODecoder's scan reads each file's camera
// details (metadata-more MD-7); a PNG without Exif scans to `.none`. Written
// before its code (contract rule 13, MD-5), turned on by MD-7. macOS only.
#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import LibraryModel
import Testing
import UniformTypeIdentifiers

@testable import LibraryApp

@Suite struct LibraryCameraDecodeTests {
    private let decoder = ImageIODecoder()
    private let captured = Date(timeIntervalSince1970: 1_780_308_000)

    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LibraryCameraDecodeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(to url: URL, as type: UTType, properties: [CFString: Any] = [:]) throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 16, height: 12, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 12))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }

    /// MD-J1 step 4's `a.jpg`: the camera, lens and exposure tags, captured at `captured`.
    private var cameraProperties: [CFString: Any] {
        let exif: [CFString: Any] = [
            kCGImagePropertyExifLensModel: "35mm F1.4", kCGImagePropertyExifISOSpeedRatings: [800],
            kCGImagePropertyExifExposureTime: 0.004, kCGImagePropertyExifFNumber: 2.0, kCGImagePropertyExifFocalLength: 35.0,
            kCGImagePropertyExifDateTimeOriginal: "2026:06:01 10:00:00", kCGImagePropertyExifOffsetTimeOriginal: "+00:00",
        ]
        let tiff: [CFString: Any] = [kCGImagePropertyTIFFMake: "Test Maker", kCGImagePropertyTIFFModel: "TM-10"]
        return [kCGImagePropertyExifDictionary: exif, kCGImagePropertyTIFFDictionary: tiff]
    }

    @Test func aJPEGsExifScansToItsCameraDetails() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(to: root.appending(path: "a.jpg"), as: .jpeg, properties: cameraProperties)

        let scan = try await decoder.scan(folder: root.path)
        let found = try #require(scan.candidates.first)
        #expect(scan.candidates.count == 1 && scan.failures.isEmpty)
        #expect(found.camera == CameraDetails(
            make: "Test Maker", model: "TM-10", lens: "35mm F1.4", iso: 800,
            exposureTime: 0.004, fNumber: 2, focalLength: 35))
        #expect(found.camera.cameraText == "Test Maker TM-10")
        #expect(found.camera.shutterText == "1/250 s" && found.camera.apertureText == "f/2")
        #expect(found.captureDate == captured)
    }

    @Test func aPNGWithoutExifScansToNone() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(to: root.appending(path: "b.png"), as: .png)

        let scan = try await decoder.scan(folder: root.path)
        let found = try #require(scan.candidates.first)
        #expect(found.kind == .png)
        #expect(found.camera == CameraDetails.none && found.camera.isEmpty)
    }
}
#endif
