// Live/LiveDevelop+Kernel.swift: the adapter onto CoreRaster for a straightened crop's pixels (crop CR-4, #3619).
// `turnedCrop` gives what `rotated(degrees:filter: .lanczos3)` followed by
// `cropped` gives, without turning the whole photo: one CoreRaster affine
// pass samples only the frame's pixels, and the frame's rows are split into
// bands that run across the cores, then stitched in order. The map is the
// turn `rotated` makes (clockwise about the photo's center, into a canvas of
// the turned bounds rounded up), shifted by the frame's origin, so a pixel
// reads the same source point either way; the sums differ only by rounding
// (within 1e-4). A frame inside `straightenCrop` is opaque, so its bands are
// copied in whole.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import Dispatch
import Synchronization

extension LiveDevelop {
    /// Rows per band, at least: fewer would spend more on the bands than on the pixels.
    static let bandRows = 32

    /// `frame` of `buffer` turned clockwise by `degrees` (any angle but a
    /// multiple of 90), sampled with lanczos3. Throws `RasterError` for a
    /// frame size or a map CoreRaster rejects.
    static func turnedCrop(_ buffer: PixelBuffer, degrees: Double, frame f: PixelRect) throws -> PixelBuffer {
        let radians = degrees * Double.pi / 180
        let (c, s) = (cos(radians), sin(radians))
        let (w, h) = (Double(buffer.width), Double(buffer.height))
        let turnedW = (w * abs(c) + h * abs(s)).rounded(.up), turnedH = (w * abs(s) + h * abs(c)).rounded(.up)
        // Source point (u, v) lands at the turned canvas's center plus the
        // turn of (u - w/2, v - h/2), less the frame's origin.
        let tx = turnedW / 2 - Double(f.x) - c * w / 2 + s * h / 2
        let ty = turnedH / 2 - Double(f.y) - s * w / 2 - c * h / 2
        let bands = max(1, min(ProcessInfo.processInfo.activeProcessorCount * 2, f.height / bandRows))
        let pieces = try inParallel(bands) { k -> (y: Int, pixels: PixelBuffer) in
            let y0 = f.height * k / bands, y1 = f.height * (k + 1) / bands
            let map = AffineMatrix(a: c, b: s, c: -s, d: c, tx: tx, ty: ty - Double(y0))
            return (y0, try buffer.transformed(map, width: f.width, height: y1 - y0, filter: .lanczos3))
        }
        if pieces.count == 1, let only = pieces.first { return only.pixels }
        var out = try PixelBuffer(width: f.width, height: f.height)
        for piece in pieces { try out.composite(piece.pixels, x: 0, y: piece.y, mode: .normal, opacity: 1) }
        return out
    }

    /// `work(0) ... work(count - 1)` across the cores, in index order;
    /// rethrows the error of the lowest index that threw.
    private static func inParallel<T: Sendable>(_ count: Int, _ work: @Sendable (Int) throws -> T) throws -> [T] {
        let results = Mutex<[Int: Result<T, any Error>]>([:])
        DispatchQueue.concurrentPerform(iterations: count) { i in
            let result = Result { try work(i) }
            results.withLock { $0[i] = result }
        }
        return try results.withLock { done in try (0..<count).compactMap { try done[$0]?.get() } }
    }
}
