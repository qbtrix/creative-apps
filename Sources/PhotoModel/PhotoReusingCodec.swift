// PhotoReusingCodec.swift: the codec Photo's headless document saves through, so one CLI edit re-encodes only the
// images it changed. It remembers every PNG it decodes, each image beside the file's own bytes, and when asked to
// encode a PNG whose pixels equal one it remembers it hands back those bytes instead of compressing again (a 24 MP
// layer costs about a second to encode). Every other read and write goes to `base`. Its memory only ever holds
// files as they were read, so copies of a document may share one. Thread-safe: the archive decodes and encodes
// across the cores. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

/// `base`, but a PNG whose pixels it read unchanged is written as the bytes it was read from.
final class PhotoReusingCodec: PhotoImageCodec {
    let base: any PhotoImageCodec
    private let read = Mutex([(image: DecodedImage, png: Data)]())

    init(_ base: any PhotoImageCodec) { self.base = base }

    var readExtensions: Set<String> { base.readExtensions }

    private let handedBack = Mutex(0)

    /// How many PNGs it holds, and how many encodes it answered with one, for tests.
    var remembered: Int { read.withLock { $0.count } }
    var reused: Int { handedBack.withLock { $0 } }

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        let image = try base.decode(data, longestSide: longestSide)
        if longestSide == nil, data.starts(with: CoreRasterImageCodec.signature) {
            read.withLock { $0.append((image, data)) }
        }
        return image
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        // Compared outside the lock, so parallel encodes don't wait on each other's compares.
        if format == .png, let png = read.withLock({ $0 }).first(where: { $0.image == image })?.png {
            handedBack.withLock { $0 += 1 }
            return png
        }
        return try base.encode(image, as: format, quality: quality)
    }
}
