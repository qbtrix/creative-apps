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
        // Each layer tile's part of the region, encoded and trimmed across
        // the cores; the trims' union is the copy, in layer pixels.
        let indices = pixels.tileIndices(in: layerArea).filter { pixels.tiles.indices.contains($0) }
        let shift = (x: content.x, y: content.y)
        let pieces = try PhotoLayerComposite.inParallel(indices.count) { job in
            try Self.piece(of: pixels, tile: indices[job], in: layerArea, mask: mask, shift: shift)
        }.compactMap { $0 }.filter { $0.kept != nil }
        guard let kept = pieces.compactMap(\.kept).reduce(nil, { $0?.union($1) ?? $1 }) else { return nil }
        var bytes = [UInt8](repeating: 0, count: kept.width * kept.height * 4)
        for piece in pieces { Self.copyRows(of: piece, into: &bytes, at: kept) }
        let image = DecodedImage(rgba8: bytes, width: kept.width, height: kept.height)
        return ClipboardImage(image: image, source: kept.offsetBy(content.x, content.y))
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
    /// is one, encoded as 8-bit bytes (`SRGBBytes`, bit for bit `rgba8()`)
    /// with no alpha left as 0, 0, 0, 0, and the bounds of the bytes with
    /// alpha above 0 (a faint pixel can round to alpha 0 in 8 bits).
    struct Piece: Sendable {
        let area: PixelRect, kept: PixelRect?, bytes: [UInt8]
    }

    static func piece(of pixels: TiledPixels, tile index: Int, in layerArea: PixelRect, mask: Mask?,
                      shift: (x: Int, y: Int)) throws -> Piece? {
        let rect = pixels.tileRect(index)
        guard pixels.tiles.indices.contains(index), let area = rect.intersection(layerArea) else { return nil }
        let tile = pixels.tiles[index], least = SRGBBytes.least, start = SRGBBytes.start
        var bytes = [UInt8](repeating: 0, count: area.width * area.height * 4)
        var minX = area.maxX, minY = area.maxY, maxX = -1, maxY = -1, at = 0
        var last = RGBA.clear, encoded: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
        for y in area.y..<area.maxY {
            for x in area.x..<area.maxX {
                var p = try tile.pixel(x: x - rect.x, y: y - rect.y)
                if let mask {
                    let c = (try? mask.coverage(x: x + shift.x, y: y + shift.y)) ?? 0
                    p = RGBA(r: p.r * c, g: p.g * c, b: p.b * c, a: p.a * c)
                }
                // Equal pixels give equal bytes; no alpha gives none.
                if p != last {
                    last = p
                    encoded = p.a > 0 ? (
                        SRGBBytes.byte(p.r / p.a, least: least, start: start),
                        SRGBBytes.byte(p.g / p.a, least: least, start: start),
                        SRGBBytes.byte(p.b / p.a, least: least, start: start),
                        UInt8((min(Double(p.a), 1) * 255).rounded())) : (0, 0, 0, 0)
                }
                bytes[at] = encoded.0; bytes[at + 1] = encoded.1
                bytes[at + 2] = encoded.2; bytes[at + 3] = encoded.3
                at += 4
                if encoded.3 > 0 { minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y) }
            }
        }
        let kept = maxX >= minX && maxY >= minY
            ? PixelRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1) : nil
        return Piece(area: area, kept: kept, bytes: bytes)
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
}
