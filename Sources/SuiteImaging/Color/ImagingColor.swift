// ImagingColor.swift: the suite's colour pipeline (suite-imaging IM-15).
// Pictures are decoded into one working space wider than sRGB, extended-range
// linear sRGB in Float32 and unclamped (a colour outside sRGB lives on as a
// negative or above-1 component, CoreColor's convention), every adjustment runs
// there, and only the end leaves it: one display step for the screen
// (`displaySteps(to:)`, appended last by the canvas and loupe routes) or one
// output transform to a file's profile at 8 or 16 bits (`toOutput`). The
// colour maths is creative-core's: CoreColor's profiles and display matrix,
// CoreRaster's profile conversion. Linux-safe.
import CoreColor
import CoreRaster
import CoreRender

/// Bits per channel of an output's samples.
public enum ImagingBitDepth: Int, Sendable, Hashable, CaseIterable {
    case eight = 8, sixteen = 16

    /// The largest sample, which stands for 1.
    public var maxSample: Int {
        switch self {
        case .eight: return 255
        case .sixteen: return 65_535
        }
    }
}

/// The display step for a screen, in both route forms: `cpu` is the list
/// the CPU backend runs one step at a time, `gpu` the operations one tone
/// program runs. Both are empty for an sRGB screen.
public struct ImagingDisplaySteps: Equatable, Sendable {
    public let cpu: [ToneAdjustment]
    public let gpu: [ToneProgram.Operation]

    /// True when the screen needs no step.
    public var isEmpty: Bool { cpu.isEmpty && gpu.isEmpty }
}

/// A picture in a file's profile: straight (not premultiplied) samples,
/// R, G, B, A per pixel, row-major, top row first, each 0...`bitDepth.maxSample`.
/// Colour samples are encoded by `profile`'s curves; alpha is linear.
public struct ImagingOutput: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let bitDepth: ImagingBitDepth
    /// The profile the samples are in, for the encoder to embed.
    public let profile: ColorProfile
    public let samples: [UInt16]

    /// The pixel at (x, y) as fractions of the largest sample (R, G, B, A),
    /// or empty outside the picture.
    public func fractions(x: Int, y: Int) -> [Double] {
        guard (0..<width).contains(x), (0..<height).contains(y) else { return [] }
        let start = (y * width + x) * 4
        guard start + 4 <= samples.count else { return [] }
        let top = Double(bitDepth.maxSample)
        return samples[start..<start + 4].map { Double($0) / top }
    }
}

public enum ImagingColor {
    /// The working space: core's linear sRGB profile, read unclamped, so values
    /// below 0 and above 1 pass through every adjustment.
    public static let workingProfile = ColorProfile.linearSRGB

    /// `buffer`, decoded from a file tagged with `profile` (premultiplied
    /// linear light in the codecs' convention), in the working space. Nothing
    /// is clamped: a colour outside sRGB keeps its negative or above-1
    /// components. Throws when core can't form the transform or a result is
    /// not finite.
    public static func toWorking(_ buffer: PixelBuffer, from profile: ColorProfile) throws -> PixelBuffer {
        try buffer.converted(from: profile, to: workingProfile)
    }

    /// The step from the working space to a screen's linear space: none for
    /// sRGB (and any space but Display P3, drawn as sRGB), core's linear sRGB
    /// to Display P3 matrix for a P3 screen. The canvas appends it last, so it
    /// is the only place a working-space colour meets the screen's gamut.
    public static func displaySteps(to screen: ColorSpace) -> ImagingDisplaySteps {
        guard screen == .displayP3 else { return ImagingDisplaySteps(cpu: [], gpu: []) }
        let rows = p3Rows()
        guard rows.count == 3 else { return ImagingDisplaySteps(cpu: [], gpu: []) }
        func row(_ r: [Float]) -> SIMD4<Float> { SIMD4(r[0], r[1], r[2], 0) }
        let mixer = ChannelMatrix(red: row(rows[0]), green: row(rows[1]), blue: row(rows[2]), monochrome: false)
        return ImagingDisplaySteps(cpu: [.channelMixer(mixer)], gpu: [.matrix(rows: rows.flatMap { $0 }, lightness: 0)])
    }

    /// Core's linear sRGB to linear Display P3 matrix as three rows of three,
    /// or empty if core ever hands back other than nine entries.
    static func p3Rows() -> [[Float]] {
        let m = DisplayTransfer.p3FromLinearSRGB
        guard m.count == 9 else { return [] }
        return (0..<3).map { r in (0..<3).map { c in Float(m[r * 3 + c]) } }
    }

    /// `buffer`, in the working space, converted to `profile` and quantized to
    /// `bitDepth`: the one place wide values meet a file's range. Colour is
    /// encoded by the profile's curves, each sample clamped to 0...1 and
    /// rounded to the nearest level; NaN gives 0. Throws as `toWorking` does.
    public static func toOutput(_ buffer: PixelBuffer, profile: ColorProfile, bitDepth: ImagingBitDepth) throws -> ImagingOutput {
        let converted = try buffer.converted(from: workingProfile, to: profile)
        let top = Double(bitDepth.maxSample)
        var samples: [UInt16] = []
        samples.reserveCapacity(converted.width * converted.height * 4)
        for y in 0..<converted.height {
            for x in 0..<converted.width {
                let p = try converted.pixel(x: x, y: y).unpremultiplied()
                // The codecs' convention: the file's numbers are the sRGB curve's encoding of these values.
                for v in [p.r, p.g, p.b] { samples.append(quantized(TransferCurve.encode(Double(v)), top)) }
                samples.append(quantized(Double(p.a), top))
            }
        }
        return ImagingOutput(width: converted.width, height: converted.height, bitDepth: bitDepth,
                             profile: profile, samples: samples)
    }

    /// A fraction as a sample of `top` levels: clamped to 0...1, rounded to nearest.
    static func quantized(_ v: Double, _ top: Double) -> UInt16 {
        guard v > 0 else { return 0 }
        return UInt16((min(v, 1) * top).rounded())
    }
}
