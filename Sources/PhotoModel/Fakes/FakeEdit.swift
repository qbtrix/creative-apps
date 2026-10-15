// Fakes/FakeEdit.swift: the edit fakes (blueprint 5.2): Cut, Copy and Paste,
// Merge Down and Flatten before PV-2. Deterministic and stateless; each does
// the least that still changes something a journey can see. Linux-safe.
import CoreRaster

/// Copies a 64 x 64 red square; pastes at the center.
public struct FakeClipboard: PixelClipboard {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage? {
        let red: [UInt8] = [255, 59, 48, 255]
        let bytes = Array((0..<(64 * 64)).map { _ in red }.joined())
        return ClipboardImage(image: DecodedImage(rgba8: bytes, width: 64, height: 64), source: selection)
    }
    public func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect {
        PixelRect(x: (canvas.width - image.image.width) / 2, y: (canvas.height - image.image.height) / 2,
                  width: image.image.width, height: image.image.height)
    }
}

/// Merge Down keeps the lower layer's pixels; Flatten keeps the bottom layer's.
public struct FakeMerging: LayerMerging {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels {
        guard let pixels = lower.pixels else { throw PhotoRefusal("Merge Down needs a pixel layer below.") }
        return PlacedPixels(pixels: pixels, x: lower.layer.offsetX, y: lower.layer.offsetY)
    }
    public func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws
        -> TiledPixels
    {
        if let bottom = layers.last?.pixels { return bottom }
        return try TiledPixels(width: canvas.width, height: canvas.height)
    }
}
