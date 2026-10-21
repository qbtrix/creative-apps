// Live/LiveSampling.swift: the live eyedropper sample (PV-9; eyedropper
// PE-5). The picture is read as straight sRGB bytes and averaged by
// SuiteKernel's `SampleRules.mean`, the one N x N mean every app's
// eyedropper shares, so Photo writes no averaging of its own. Linux-safe.
import CoreRaster
import SuiteKernel

enum LiveSampling { static func make() -> any ColorSampling { LiveColorSampling() } }

/// The mean of the square centred on the point, over the picture's pixels
/// that are inside it and not fully transparent; nil when there are none.
struct LiveColorSampling: ColorSampling {
    var unavailableHelp: String? { nil }

    func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor? {
        guard let bytes = try? picture.rgba8() else { return nil }
        let (width, height) = (picture.width, picture.height)
        let mean = SampleRules.mean(x: center.x, y: center.y, size: size) { x, y in
            guard (0..<width).contains(x), (0..<height).contains(y) else { return nil }
            let i = (y * width + x) * 4
            guard i + 3 < bytes.count else { return nil }
            return SampleRGBA(r: bytes[i], g: bytes[i + 1], b: bytes[i + 2], a: bytes[i + 3])
        }
        guard let mean else { return nil }
        func byte(_ channel: Double) -> UInt8 { UInt8(clamping: SampleRules.byte(channel)) }
        return SampledColor(red: byte(mean.r), green: byte(mean.g), blue: byte(mean.b))
    }
}
