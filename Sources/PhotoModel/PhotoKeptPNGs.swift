// PhotoKeptPNGs.swift: the PNG of each layer image a window's last autosave
// wrote, kept with the pixels it was encoded from (#5312), so the next write
// encodes only the layers and masks whose pixels changed: one after a stroke,
// not every layer of the image. Reuse is keyed on the layer id (a mask apart
// from its layer's pixels) and checked with `TiledPixels ==`, which is cheap
// for an untouched layer because its tiles share their storage with the kept
// copy, and right after undo, a reopen or a reused id because it compares
// pixels, not counters. Each call keeps exactly the images it was given, so
// a removed layer's tiles are let go. One value per window and codec; the
// autosave adopts the new value only once its write landed. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct PhotoKeptPNGs: Sendable {
    struct Key: Hashable, Sendable {
        let id: PhotoLayer.ID
        let mask: Bool
    }

    private var kept: [Key: (pixels: TiledPixels, png: Data)] = [:]

    public init() {}

    /// The PNG of each of `pixels` and `masks`: the kept one while its pixels are unchanged, else encoded
    /// through `codec`, across the cores. Keeps what it returns, and nothing else.
    mutating func pngs(
        pixels: [PhotoLayer.ID: TiledPixels], masks: [PhotoLayer.ID: TiledPixels], codec: any PhotoImageCodec
    ) throws -> (pixels: [PhotoLayer.ID: Data], masks: [PhotoLayer.ID: Data]) {
        let images = pixels.map { (Key(id: $0.key, mask: false), $0.value) } + masks.map { (Key(id: $0.key, mask: true), $0.value) }
        let old = kept
        let pngs = try PhotoLayerComposite.inParallel(images.count) { i in
            let (key, tiles) = images[i]
            if let kept = old[key], kept.pixels == tiles { return kept.png }
            let image = DecodedImage(rgba8: try tiles.rgba8(), width: tiles.width, height: tiles.height)
            return try codec.encode(image, as: .png, quality: 1)
        }
        kept = [:]
        var result: (pixels: [PhotoLayer.ID: Data], masks: [PhotoLayer.ID: Data]) = ([:], [:])
        for ((key, tiles), png) in zip(images, pngs) {
            kept[key] = (tiles, png)
            if key.mask { result.masks[key.id] = png } else { result.pixels[key.id] = png }
        }
        return result
    }
}
