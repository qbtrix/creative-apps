// PhotoPNGMemoTests.swift: a window's autosave encodes only the layers that changed since its last write
// (#5312). On a 60-layer image, the write after one stroke encodes that one layer (plus the merged picture
// and thumbnail the archive always makes), not all 60, and its package is byte for byte the one a full encode
// makes. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization
import Testing

@testable import PhotoModel

@Suite struct PhotoPNGMemoTests {
    /// RawCodec that counts its PNG encodes, across the archive's parallel encodes.
    final class CountingCodec: PhotoImageCodec {
        private let encodes = Mutex(0)
        var count: Int { encodes.withLock { $0 } }
        func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage { try RawCodec().decode(data, longestSide: longestSide) }
        func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
            encodes.withLock { $0 += 1 }
            return try RawCodec().encode(image, as: format, quality: quality)
        }
    }

    @Test func theWriteAfterOneStrokeEncodesOnlyThatLayer() throws {
        var workspace = try whiteImage(64, 64)
        for _ in 1..<60 { workspace.addLayer() }
        #expect(workspace.pixels.count == 60)
        let (archive, codec, memo) = (LiveArchive(), CountingCodec(), PhotoPNGMemo())
        _ = try #require(try workspace.recoveryEntry(now: 1, archive: archive, codec: codec, reusing: memo))
        let first = codec.count
        stroke(&workspace, .brush, from: point(10, 10), to: point(40, 30))
        let entry = try #require(try workspace.recoveryEntry(now: 2, archive: archive, codec: codec, reusing: memo))
        let second = codec.count - first
        #expect(second == first - 59, "the second write encoded \(second) images; the first, every layer, \(first)")
        let full = try #require(try workspace.recoveryEntry(now: 2, archive: archive, codec: RawCodec()))
        #expect(entry.package == full.package, "a kept PNG is the same bytes a fresh encode makes")
    }
}
