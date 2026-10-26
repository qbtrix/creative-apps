// PhotoKeptPNGsTests.swift: an autosave reuses the PNG of every layer whose pixels
// it already encoded (#5312). On a 60-layer image the write after one stroke
// encodes that one layer, not 60, and every reused write holds the bytes a
// fresh write would: the same files, and a restore gives back the same 8-bit
// pixels. Encodes are counted, never timed. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import Synchronization
import Testing

/// RawCodec, counting its encodes.
private final class CountingCodec: PhotoImageCodec {
    let encodes = Mutex(0)
    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage { try RawCodec().decode(data, longestSide: longestSide) }
    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        encodes.withLock { $0 += 1 }
        return try RawCodec().encode(image, as: format, quality: quality)
    }
    var count: Int { encodes.withLock { $0 } }
}

@Suite struct PhotoKeptPNGsTests {
    private let archive = PhotoServices.live.archive

    /// A white 64 x 64 Background under 59 filled layers, each its own color: 60 pixel layers, dirty.
    private func sixtyLayers() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        for n in 1..<60 { addFilledLayer(&workspace, red: UInt8(n * 4), green: UInt8(255 - n * 4), blue: UInt8(n)) }
        return workspace
    }

    /// The package a write with nothing kept makes.
    private func fresh(_ workspace: PhotoWorkspace) throws -> PhotoPackage {
        try #require(try workspace.recoveryEntry(now: 1, archive: archive, codec: RawCodec())).package
    }

    @Test func theWriteAfterOneStrokeEncodesOnlyThatLayer() throws {
        var workspace = try sixtyLayers()
        let codec = CountingCodec()
        var kept = PhotoKeptPNGs()
        _ = try workspace.recoveryEntry(now: 1, archive: archive, codec: codec, reusing: &kept)
        #expect(codec.count == 60, "the first write encodes every layer once")
        stroke(&workspace, .brush, from: point(8, 8), to: point(40, 40))
        let entry = try #require(try workspace.recoveryEntry(now: 2, archive: archive, codec: codec, reusing: &kept))
        #expect(codec.count == 61, "the write after one stroke encoded \(codec.count - 60) layers, not 1")
        #expect(entry.package == (try fresh(workspace)), "a reused PNG differs from a fresh write's")
        var restored = PhotoWorkspace(services: .fake)
        try restored.restore(entry, archive: archive, codec: RawCodec())
        #expect(try restored.snapshot().pixels == workspace.snapshot().pixels)
        _ = try workspace.recoveryEntry(now: 3, archive: archive, codec: codec, reusing: &kept)
        #expect(codec.count == 61, "an unchanged image was encoded again")
    }

    /// The PNGs follow the layers, not their places in the stack: a move renames every file below the moved
    /// layer and encodes nothing, a mask keeps its own PNG apart from its layer's, and a removed layer's goes.
    @Test func keptPNGsFollowTheLayersAndTheirMasks() throws {
        func image(_ seed: Int) -> DecodedImage {
            DecodedImage(rgba8: (0..<6 * 4 * 4).map { UInt8(($0 * 7 + seed) % 256) }, width: 6, height: 4)
        }
        var top = PhotoLayer(id: "layer-3", name: "Top")
        top.hasMask = true
        let middle = PhotoLayer(id: "layer-2", name: "Middle"), background = PhotoLayer(id: "layer-1", name: "Background")
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openDocument(PhotoDocumentSnapshot(
            canvas: CanvasSize(width: 6, height: 4), layers: [top, middle, background],
            pixels: ["layer-3": image(1), "layer-2": image(2), "layer-1": image(3)], masks: ["layer-3": image(4)],
            selectedLayerID: "layer-3"), name: "masked.ora")
        let codec = CountingCodec()
        var kept = PhotoKeptPNGs()
        workspace.moveLayers(fromOffsets: [0], toOffset: 2)
        _ = try workspace.recoveryEntry(now: 1, archive: archive, codec: codec, reusing: &kept)
        #expect(codec.count == 4, "three layers and one mask")
        workspace.moveLayers(fromOffsets: [1], toOffset: 0)
        let moved = try #require(try workspace.recoveryEntry(now: 2, archive: archive, codec: codec, reusing: &kept))
        #expect(codec.count == 4, "a move encoded \(codec.count - 4) PNGs")
        #expect(moved.package == (try fresh(workspace)))
        let gone = workspace.removeLayer("layer-2")
        #expect(gone)
        let removed = try #require(try workspace.recoveryEntry(now: 3, archive: archive, codec: codec, reusing: &kept))
        #expect(removed.package == (try fresh(workspace)))
        workspace.undo()
        let back = try #require(try workspace.recoveryEntry(now: 4, archive: archive, codec: codec, reusing: &kept))
        #expect(codec.count == 5, "a removed layer's PNG wasn't let go")
        #expect(back.package == (try fresh(workspace)))
    }
}
