// HueSaturation.swift: the Hue/Saturation adjustment, which CoreRaster has no
// operation for yet. Hue turns colors around the gray axis, saturation pushes
// them away from or toward gray, both through the color matrices of the W3C
// Filter Effects spec (feColorMatrix hueRotate and saturate), applied to
// straight linear colors; lightness mixes toward white (positive) or black
// (negative). Alpha never changes; negative results clamp to 0.
// ponytail: per-pixel through pixel/setPixel in linear light; move it into
// CoreRaster (and an OKLab hue) once Library needs it too. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import CoreRaster

extension PixelBuffer {
    /// Hue in degrees, saturation and lightness in percent (-100...100).
    /// Zeros return the buffer unchanged.
    func hueSaturation(hue: Double, saturation: Double, lightness: Double) throws -> PixelBuffer {
        guard hue != 0 || saturation != 0 || lightness != 0 else { return self }
        let m = Self.colorMatrix(hue: hue, saturation: saturation)
        let l = Float(min(max(lightness, -100), 100) / 100)
        var result = self
        for y in 0..<height {
            for x in 0..<width {
                let p = try pixel(x: x, y: y).unpremultiplied()
                func light(_ v: Float) -> Float {
                    let c = max(v, 0)
                    return l >= 0 ? c + (1 - c) * l : c * (1 + l)
                }
                let r = light(m[0] * p.r + m[1] * p.g + m[2] * p.b)
                let g = light(m[3] * p.r + m[4] * p.g + m[5] * p.b)
                let b = light(m[6] * p.r + m[7] * p.g + m[8] * p.b)
                try result.setPixel(x: x, y: y, RGBA(r: r, g: g, b: b, a: p.a).premultiplied())
            }
        }
        return result
    }

    /// hueRotate(hue) times saturate(1 + saturation / 100), row-major 3x3.
    static func colorMatrix(hue: Double, saturation: Double) -> [Float] {
        let s = 1 + min(max(saturation, -100), 100) / 100
        let saturate: [Double] = [
            0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s,
            0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s,
            0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s,
        ]
        let angle = min(max(hue, -180), 180) * .pi / 180
        let (c, n) = (cos(angle), sin(angle))
        let rotate: [Double] = [
            0.213 + c * 0.787 - n * 0.213, 0.715 - c * 0.715 - n * 0.715, 0.072 - c * 0.072 + n * 0.928,
            0.213 - c * 0.213 + n * 0.143, 0.715 + c * 0.285 + n * 0.140, 0.072 - c * 0.072 - n * 0.283,
            0.213 - c * 0.213 - n * 0.787, 0.715 - c * 0.715 + n * 0.715, 0.072 + c * 0.928 + n * 0.072,
        ]
        return (0..<9).map { i in
            let (row, column) = (i / 3, i % 3)
            return Float((0..<3).reduce(0.0) { $0 + rotate[row * 3 + $1] * saturate[$1 * 3 + column] })
        }
    }
}
