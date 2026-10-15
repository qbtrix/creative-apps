// Live/LiveEdit.swift: the live edit use cases (PV-2). `LiveClipboard` is
// Copy and Paste placement; `LiveMerging` (LiveMerging.swift) is Merge Down
// and Flatten. Linux-safe.
import CoreRaster

enum LiveEdit {
    static func clipboard() -> any PixelClipboard { LiveClipboard() }
    static func merging() -> any LayerMerging { LiveMerging() }
}

/// Copy takes the layer's pixels inside the selection (the whole layer with
/// none), each weighted by the selection mask's coverage when there is one,
/// cut to the bounds of what is not transparent and encoded as 8-bit straight
/// sRGB; `source` is that cut rect in canvas pixels. Paste goes back on its
/// source rect while that overlaps the canvas, else centered on the view.
struct LiveClipboard: PixelClipboard {
    var unavailableHelp: String? { nil }

    func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage? {
        let pixels = content.pixels
        let bounds = PixelRect(x: content.x, y: content.y, width: pixels.width, height: pixels.height)
        guard let region = (selection ?? bounds).intersection(bounds) else { return nil }
        var buffer = try PixelBuffer(width: region.width, height: region.height)
        // The region's pixels with any alpha, in region pixels.
        var minX = region.width, minY = region.height, maxX = -1, maxY = -1
        let layerArea = region.offsetBy(-content.x, -content.y)
        for index in pixels.tileIndices(in: layerArea) where pixels.tiles.indices.contains(index) {
            let tileRect = pixels.tileRect(index)
            guard let area = tileRect.intersection(layerArea) else { continue }
            let tile = pixels.tiles[index]
            for y in area.y..<area.maxY {
                for x in area.x..<area.maxX {
                    var pixel = try tile.pixel(x: x - tileRect.x, y: y - tileRect.y)
                    if let mask {
                        let c = (try? mask.coverage(x: x + content.x, y: y + content.y)) ?? 0
                        pixel = RGBA(r: pixel.r * c, g: pixel.g * c, b: pixel.b * c, a: pixel.a * c)
                    }
                    guard pixel.a > 0 else { continue }
                    let rx = x - layerArea.x, ry = y - layerArea.y
                    try buffer.setPixel(x: rx, y: ry, pixel)
                    minX = min(minX, rx); minY = min(minY, ry); maxX = max(maxX, rx); maxY = max(maxY, ry)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let kept = try buffer.cropped(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        let bytes = try kept.rgba8()
        // A faint pixel can round to alpha 0 in 8 bits: cut again on the bytes.
        guard let trim = Self.opaqueBounds(bytes, width: kept.width, height: kept.height) else { return nil }
        let image = DecodedImage(
            rgba8: Self.crop(bytes, width: kept.width, to: trim), width: trim.width, height: trim.height)
        let source = trim.offsetBy(region.x + minX, region.y + minY)
        return ClipboardImage(image: image, source: source)
    }

    func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect {
        if let source = image.source, source.intersection(canvas.rect) != nil { return source }
        let w = image.image.width, h = image.image.height
        let cx = center.x.isFinite ? center.x : Double(canvas.width) / 2
        let cy = center.y.isFinite ? center.y : Double(canvas.height) / 2
        // At least one pixel stays on the canvas: x in 1 - w ... width - 1.
        let x = max(Double(1 - w), min(Double(canvas.width - 1), (cx - Double(w) / 2).rounded(.down)))
        let y = max(Double(1 - h), min(Double(canvas.height - 1), (cy - Double(h) / 2).rounded(.down)))
        return PixelRect(x: Int(x), y: Int(y), width: w, height: h)
    }

    /// The bounds of the bytes' pixels with alpha above 0, or nil when none.
    static func opaqueBounds(_ bytes: [UInt8], width: Int, height: Int) -> PixelRect? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let a = (y * width + x) * 4 + 3
                guard bytes.indices.contains(a), bytes[a] > 0 else { continue }
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The rows of `rect` from bytes `width` pixels wide.
    static func crop(_ bytes: [UInt8], width: Int, to rect: PixelRect) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(rect.width * rect.height * 4)
        for y in rect.y..<rect.maxY {
            let start = (y * width + rect.x) * 4, end = start + rect.width * 4
            guard start >= 0, end <= bytes.count else { continue }
            out.append(contentsOf: bytes[start..<end])
        }
        return out
    }
}
