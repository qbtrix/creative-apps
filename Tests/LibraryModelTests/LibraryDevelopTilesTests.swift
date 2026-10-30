// LibraryDevelopTilesTests.swift: the fast develop paths give core's pixels
// and counts exactly (quality gate #5953, #6061). The tiled develop
// (`LiveDevelop.run`) and the banded one for small buffers (`banded`) equal
// one pass over the whole buffer (`serial`) with
// every control and Invert on, partial edge tiles and translucent pixels
// included; `LiveHistogram` equals CoreRaster's sRGB histogram on renders,
// on seeded noise with transparent, translucent and out-of-range pixels, and
// bin for bin on every float of each table run that straddles two bins.
// The export's parallel shrink (`LiveResize`) equals CoreRaster's `resized`.
// Runs on Linux and macOS.
@testable import LibraryModel
import CoreRaster
import SuiteImaging
import Testing

private struct Seeded: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}

/// `width` x `height` premultiplied noise: one pixel in 9 transparent, one in 5 translucent, values up to 1.5.
private func noise(width: Int, height: Int, seed: UInt64) throws -> PixelBuffer {
    var rng = Seeded(state: seed)
    var b = try PixelBuffer(width: width, height: height)
    for y in 0..<height {
        for x in 0..<width {
            let roll = Int.random(in: 0..<45, using: &rng)
            let a: Float = roll % 9 == 0 ? 0 : roll % 5 == 0 ? .random(in: 0.01...1, using: &rng) : 1
            let c = { Float.random(in: -0.2...1.5, using: &rng) * a }
            try b.setPixel(x: x, y: y, RGBA(r: c(), g: c(), b: c(), a: a))
        }
    }
    return b
}

@Suite struct LibraryDevelopTilesTests {
    private let everything = everyControlButColor().setting(.vibrance, to: 40).setting(.saturation, to: 20)
        .setting(kinds: [.invert])

    @Test func theTiledDevelopIsOnePassOverTheWholeBuffer() throws {
        let steps = LiveDevelop.steps(for: everything) + AdjustKinds.adjustments(everything.kinds)
        for buffer in [try developGradient(width: 600, height: 400), try noise(width: 300, height: 520, seed: 7),
                       try developGradient(width: 40, height: 30)] {
            let tiled = try LiveDevelop.run(steps, on: buffer)
            #expect(tiled == (try LiveDevelop.serial(steps, on: buffer)), "\(buffer.width)x\(buffer.height)")
            #expect(tiled != buffer)
            for bands in [3, 7, 12] {
                #expect(try LiveDevelop.banded(steps, on: buffer, bands: bands) == tiled, "\(bands) bands")
            }
        }
    }

    /// The export's shrink (`LiveResize`) is core's `resized`, pixel for pixel: shrinks that run either pass
    /// first, a grow, one side only, sizes off the 256 px grid and translucent noise.
    @Test func theParallelResizeIsCoresResize() throws {
        let cases: [(PixelBuffer, Int, Int)] = [
            (try noise(width: 700, height: 530, seed: 11), 233, 177), (try noise(width: 530, height: 700, seed: 12), 177, 233),
            (try developGradient(width: 900, height: 600), 300, 199), (try noise(width: 300, height: 200, seed: 13), 613, 401),
            (try noise(width: 520, height: 260, seed: 14), 257, 260), (try noise(width: 260, height: 520, seed: 15), 260, 255),
            (try noise(width: 40, height: 30, seed: 16), 40, 30)]
        for (buffer, width, height) in cases {
            let core = try buffer.resized(width: width, height: height, filter: .lanczos3)
            #expect(try LiveResize.resized(buffer, width: width, height: height) == core,
                    "\(buffer.width)x\(buffer.height) to \(width)x\(height)")
        }
    }

    @Test func theHistogramIsCoresOnRendersAndNoise() throws {
        let gradient = try developGradient(width: 600, height: 400)
        for buffer in [gradient, try LiveDevelop().render(gradient, settings: everything),
                       try noise(width: 333, height: 211, seed: 42), try noise(width: 1, height: 1, seed: 3)] {
            #expect(try LiveDevelop().histogram(of: buffer) == handHistogram(buffer), "\(buffer.width)x\(buffer.height)")
        }
    }

    @Test func everyFloatInARunThatStraddlesTwoBinsGetsCoresBin() {
        let shift: UInt32 = 13, one = Float(1).bitPattern
        var checked = 0
        for run in 0...(one >> shift) {
            let first = run << shift, last = min(first | ((1 << shift) - 1), one)
            let ends = (LiveHistogram.bin(Float(bitPattern: first)), LiveHistogram.bin(Float(bitPattern: last)))
            // A run with one bin: its two ends (all the table looks at) and its middle.
            let probes: [UInt32] = ends.0 == ends.1 ? [first, (first + last) / 2, last] : Array(first...last)
            for bits in probes where LiveHistogram.fastBin(Float(bitPattern: bits)) != LiveHistogram.bin(Float(bitPattern: bits)) {
                Issue.record("float \(Float(bitPattern: bits)) (bits \(bits)) gets the wrong bin")
            }
            checked += probes.count
        }
        #expect(checked > 255 * 2)
        #expect(LiveHistogram.fastBin(0) == 0 && LiveHistogram.fastBin(1) == 255)
    }
}
