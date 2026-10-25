// Live/LiveAdjustmentLayers.swift: the live adjustment layers (PV-6, AL-1 of
// photo-adjustment-layers). A layer's settings run through the same
// `AdjustmentSettings.applied(to:)` the whole-image adjustments use
// (PhotoRender.swift: exposure, levels, curves, hue/saturation, in that
// order) with Blur switched off, since a blur reads neighbours and stays
// whole-image. At opacity 1, normal blend and no mask that result is the
// answer, bit for bit. Otherwise it goes back onto `below` through
// CoreRaster's composite with the layer's blend mode and opacity, each pixel
// first weighted by the mask's gray (its premultiplied red, clamped to 0...1),
// so a gray of 0.5 mixes like opacity 0.5. Linux-safe.
import CoreRaster

enum LiveAdjustmentLayers { static func make() -> any AdjustmentLayering { LiveAdjustmentLayering() } }

struct LiveAdjustmentLayering: AdjustmentLayering {
    var unavailableHelp: String? { nil }
    var kinds: [AdjustmentKind] { [.exposure, .levels, .curves, .hueSaturation] }

    /// Throws `RasterError.invalid` when `opacity` is outside 0...1 or not
    /// finite, when `mask` is not the size of `below`, or when an adjustment fails.
    func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double,
                  blendMode: BlendMode, mask: PixelBuffer?) throws -> PixelBuffer {
        var layerSettings = settings
        layerSettings.apply(.setEnabled(.blur, false))
        let adjusted = try layerSettings.applied(to: below)
        if opacity == 1, blendMode == .normal, mask == nil { return adjusted }
        guard let mask else {
            return try CoreRaster.composite(adjusted, onto: below, mode: blendMode, opacity: Float(opacity))
        }
        guard mask.width == below.width, mask.height == below.height else {
            throw RasterError.invalid(
                "mask \(mask.width)x\(mask.height) does not match \(below.width)x\(below.height)")
        }
        // Scaling a premultiplied pixel scales its alpha and keeps its color,
        // which is what the composite's opacity does, one pixel at a time.
        var weighted = adjusted
        for y in 0..<below.height {
            for x in 0..<below.width {
                let gray = min(max(try mask.pixel(x: x, y: y).r, 0), 1)
                guard gray < 1 else { continue }
                let p = try adjusted.pixel(x: x, y: y)
                try weighted.setPixel(x: x, y: y, RGBA(r: p.r * gray, g: p.g * gray, b: p.b * gray, a: p.a * gray))
            }
        }
        return try CoreRaster.composite(weighted, onto: below, mode: blendMode, opacity: Float(opacity))
    }
}
