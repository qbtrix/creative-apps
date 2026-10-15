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
        let layerArea = region.offsetBy(-content.x, -content.y)
        // Each layer tile's part of the region, encoded across the cores.
        let indices = pixels.tileIndices(in: layerArea).filter { pixels.tiles.indices.contains($0) }
        let shift = (x: content.x, y: content.y)
        let pieces = try PhotoLayerComposite.inParallel(indices.count) { job in
            try Self.piece(of: pixels, tile: indices[job], in: layerArea, mask: mask, shift: shift)
        }.compactMap { $0 }
        // The pixels with any alpha, in layer pixels, as 8-bit bytes.
        guard let kept = pieces.compactMap(\.kept).reduce(nil, { $0?.union($1) ?? $1 }) else { return nil }
        var bytes = [UInt8](repeating: 0, count: kept.width * kept.height * 4)
        for piece in pieces { Self.copyRows(of: piece, into: &bytes, at: kept) }
        // A faint pixel can round to alpha 0 in 8 bits: cut again on the bytes.
        guard let trim = Self.opaqueBounds(bytes, width: kept.width, height: kept.height) else { return nil }
        let image = DecodedImage(
            rgba8: Self.crop(bytes, width: kept.width, to: trim), width: trim.width, height: trim.height)
        let source = trim.offsetBy(kept.x + content.x, kept.y + content.y)
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

    /// One layer tile's part of a copy: its pixels inside `layerArea`, each
    /// weighted by `mask` (canvas pixels, layer pixel plus `shift`) when there
    /// is one and cleared when that leaves no alpha, encoded as 8-bit bytes,
    /// with the bounds of what has alpha.
    struct Piece: Sendable {
        let area: PixelRect, kept: PixelRect?, bytes: [UInt8]
    }

    static func piece(of pixels: TiledPixels, tile index: Int, in layerArea: PixelRect, mask: Mask?,
                      shift: (x: Int, y: Int)) throws -> Piece? {
        let rect = pixels.tileRect(index)
        guard pixels.tiles.indices.contains(index), let area = rect.intersection(layerArea) else { return nil }
        var piece = try pixels.tiles[index].cropped(
            x: area.x - rect.x, y: area.y - rect.y, width: area.width, height: area.height)
        var minX = area.maxX, minY = area.maxY, maxX = -1, maxY = -1
        for y in area.y..<area.maxY {
            for x in area.x..<area.maxX {
                var pixel = try piece.pixel(x: x - area.x, y: y - area.y)
                if let mask {
                    let c = (try? mask.coverage(x: x + shift.x, y: y + shift.y)) ?? 0
                    pixel = RGBA(r: pixel.r * c, g: pixel.g * c, b: pixel.b * c, a: pixel.a * c)
                    if pixel.a > 0 { try piece.setPixel(x: x - area.x, y: y - area.y, pixel) }
                }
                guard pixel.a > 0 else {
                    if pixel != .clear { try piece.setPixel(x: x - area.x, y: y - area.y, .clear) }
                    continue
                }
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        let kept = maxX >= minX && maxY >= minY
            ? PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1) : nil
        return Piece(area: area, kept: kept, bytes: try piece.rgba8())
    }

    /// `piece`'s bytes inside `rect` written into `bytes`, which hold `rect`.
    static func copyRows(of piece: Piece, into bytes: inout [UInt8], at rect: PixelRect) {
        guard let overlap = piece.area.intersection(rect) else { return }
        let count = overlap.width * 4
        for y in overlap.y..<overlap.maxY {
            let from = ((y - piece.area.y) * piece.area.width + overlap.x - piece.area.x) * 4
            let to = ((y - rect.y) * rect.width + overlap.x - rect.x) * 4
            guard from >= 0, from + count <= piece.bytes.count, to >= 0, to + count <= bytes.count else { continue }
            bytes.replaceSubrange(to..<(to + count), with: piece.bytes[from..<(from + count)])
        }
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
