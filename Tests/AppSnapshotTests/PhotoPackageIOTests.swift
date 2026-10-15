// PhotoPackageIOTests.swift: PhotoPackageIO, a document's bytes on disk off
// the main actor (photo-documents D-6). PF-1 through ImageIOCodec and the
// live archive: a layered snapshot written to a temp file and read back
// decodes to the same 8-bit bytes and fields; the encode runs off the main
// thread; a write into a read-only folder throws and leaves no file. Pixels
// are opaque or all zero, which ImageIO's premultiplied decode keeps exactly.
// macOS only.
#if os(macOS)
import CoreRaster
import Foundation
import Synchronization
import Testing

@testable import PhotoApp
@testable import PhotoModel

/// ImageIOCodec that records, from inside each call, whether it ran on the main thread.
private final class ThreadProbeCodec: PhotoImageCodec {
    let onMain = Mutex<[Bool]>([])
    private let codec = ImageIOCodec()

    private func record() {
        let main = Thread.isMainThread
        onMain.withLock { $0.append(main) }
    }

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        record()
        return try codec.decode(data, longestSide: longestSide)
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        record()
        return try codec.encode(image, as: format, quality: quality)
    }
}

@MainActor
@Suite struct PhotoPackageIOTests {
    private let archive = PhotoServices.live.archive

    /// A fresh temp folder.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "PhotoPackageIOTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Distinct opaque bytes per pixel, every fifth pixel all zero.
    private func image(_ width: Int, _ height: Int, seed: Int) -> DecodedImage {
        let bytes = (0..<width * height).flatMap { i -> [UInt8] in
            if i % 5 == 4 { return [0, 0, 0, 0] }
            return [UInt8((i * 7 + seed) % 256), UInt8((i * 13 + seed * 3) % 256), UInt8((i * 29 + seed) % 256), 255]
        }
        return DecodedImage(rgba8: bytes, width: width, height: height)
    }

    /// Top first: an adjustment layer with a mask, a hidden multiply layer at
    /// an offset with a disabled mask and lowered opacity, and the Background.
    private func snapshot() -> PhotoDocumentSnapshot {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(0.75))
        settings.apply(.hue(30))
        var curves = PhotoLayer(id: "layer-7", name: "Curves")
        curves.kind = .adjustment(settings)
        curves.hasMask = true
        var paint = PhotoLayer(id: "layer-3", name: "Paint", isVisible: false, opacity: 0.37, blendMode: .multiply)
        paint.offsetX = -2; paint.offsetY = 3
        paint.hasMask = true; paint.isMaskEnabled = false
        let background = PhotoLayer(id: "layer-1", name: "Background")
        var global = AdjustmentSettings()
        global.apply(.saturation(-40))
        global.apply(.blurSigma(1.5))
        return PhotoDocumentSnapshot(
            canvas: CanvasSize(width: 6, height: 4), layers: [curves, paint, background],
            pixels: ["layer-3": image(3, 2, seed: 5), "layer-1": image(6, 4, seed: 0)],
            masks: ["layer-7": image(6, 4, seed: 9), "layer-3": image(3, 2, seed: 11)],
            adjustments: global, selectedLayerID: "layer-3")
    }

    @Test func everyFieldSurvivesImageIO() async throws {
        let original = snapshot()
        let url = try folder().appending(path: "Layers.ora")
        try await PhotoPackageIO.write(original, to: url, archive: archive, codec: ImageIOCodec())
        let package = try await PhotoPackageIO.read(from: url, archive: archive)
        #expect(try archive.decode(package, codec: ImageIOCodec()) == original)

        var model = PhotoWorkspace(services: .live)
        try model.openDocument(package, name: "Layers.ora", codec: ImageIOCodec())
        #expect(model.layers.map(\.id) == ["layer-7", "layer-3", "layer-1"])
        #expect(model.isDirty == false)
    }

    @Test func writesOffMain() async throws {
        let codec = ThreadProbeCodec()
        let url = try folder().appending(path: "Layers.ora")
        try await PhotoPackageIO.write(snapshot(), to: url, archive: archive, codec: codec)
        let calls = codec.onMain.withLock { $0 }
        #expect(!calls.isEmpty)
        #expect(!calls.contains(true))
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    }

    @Test func failedWriteLeavesNoFile() async throws {
        let locked = try folder()
        let manager = FileManager.default
        try manager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: locked.path(percentEncoded: false))
        defer { try? manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: locked.path(percentEncoded: false)) }
        let url = locked.appending(path: "Layers.ora")
        await #expect(throws: (any Error).self) {
            try await PhotoPackageIO.write(snapshot(), to: url, archive: archive, codec: ImageIOCodec())
        }
        #expect(manager.fileExists(atPath: url.path(percentEncoded: false)) == false)
        #expect(try manager.contentsOfDirectory(atPath: locked.path(percentEncoded: false)).isEmpty)
    }
}
#endif
