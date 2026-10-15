// Live/LiveCrop.swift: the live crop sizing (PV-3, photo-crop CP-1). Typed
// X/Y/W/H clamp to the canvas, an aspect lock makes one side follow the
// other, a drag grows from its anchor toward the pointer, and an aspect
// reshapes a crop about its center. Every result lies inside the canvas and
// is at least 1 x 1. Linux-safe.
import CoreRaster

enum LiveCrop { static func make() -> any CropSizing { LiveCropSizing() } }

struct LiveCropSizing: CropSizing {
    var unavailableHelp: String? { nil }

    /// Width : height, both at least 1; nil when the crop is free.
    func ratio(_ aspect: CropAspect, canvas: CanvasSize) -> (w: Int, h: Int)? {
        switch aspect {
        case .free: nil
        case .original: canvas.width >= 1 && canvas.height >= 1 ? (canvas.width, canvas.height) : nil
        case .ratio(let w, let h): w >= 1 && h >= 1 ? (w, h) : nil
        }
    }

    func setting(_ field: CropField, to value: Int, in crop: PixelRect, aspect: CropAspect,
                 canvas: CanvasSize) -> PixelRect {
        let (cw, ch) = bounds(canvas)
        var r = inside(crop, cw, ch)
        let lock = ratio(aspect, canvas: canvas)
        switch field {
        case .x: r.x = clamp(value, 0, cw - r.width)
        case .y: r.y = clamp(value, 0, ch - r.height)
        case .width:
            r.width = clamp(value, 1, cw - r.x)
            guard let lock else { break }
            r.height = max(1, follow(r.width, lock.h, lock.w))
            if r.y + r.height > ch {
                r.height = ch - r.y
                r.width = clamp(follow(r.height, lock.w, lock.h), 1, cw - r.x)
            }
        case .height:
            r.height = clamp(value, 1, ch - r.y)
            guard let lock else { break }
            r.width = max(1, follow(r.height, lock.w, lock.h))
            if r.x + r.width > cw {
                r.width = cw - r.x
                r.height = clamp(follow(r.width, lock.h, lock.w), 1, ch - r.y)
            }
        }
        return r
    }

    func dragged(from anchor: Mask.Point, to point: Mask.Point, aspect: CropAspect, canvas: CanvasSize) -> PixelRect {
        let (cw, ch) = bounds(canvas)
        let a = pinned(anchor, cw, ch), p = pinned(point, cw, ch)
        var r = PixelRect(from: a, to: p)
        if r.width < 1 { r = PixelRect(x: min(r.x, cw - 1), y: r.y, width: 1, height: r.height) }
        if r.height < 1 { r = PixelRect(x: r.x, y: min(r.y, ch - 1), width: r.width, height: 1) }
        guard let lock = ratio(aspect, canvas: canvas) else { return r }
        // The side that is larger for the ratio wins; the other follows.
        let wanted = Double(r.width) * Double(lock.h) >= Double(r.height) * Double(lock.w)
            ? (w: r.width, h: max(1, follow(r.width, lock.h, lock.w)))
            : (w: max(1, follow(r.height, lock.w, lock.h)), h: r.height)
        // Grow from the anchor's edges toward the pointer; shrink both sides
        // together until the rect fits the room on that side.
        let leftward = p.x < a.x, upward = p.y < a.y
        let room = (w: leftward ? r.maxX : cw - r.x, h: upward ? r.maxY : ch - r.y)
        let size = largest(lock, within: min(wanted.w, room.w), min(wanted.h, room.h))
        return PixelRect(x: leftward ? r.maxX - size.w : r.x, y: upward ? r.maxY - size.h : r.y,
                         width: size.w, height: size.h)
    }

    func applying(_ aspect: CropAspect, to crop: PixelRect?, canvas: CanvasSize) -> PixelRect {
        let (cw, ch) = bounds(canvas)
        let full = PixelRect(x: 0, y: 0, width: cw, height: ch)
        let base = crop.flatMap { $0.intersection(full) } ?? full
        guard let lock = ratio(aspect, canvas: canvas) else { return base }
        let size = largest(lock, within: base.width, base.height)
        return PixelRect(x: base.x + (base.width - size.w) / 2, y: base.y + (base.height - size.h) / 2,
                         width: size.w, height: size.h)
    }

    func swapped(_ aspect: CropAspect, canvas: CanvasSize) -> CropAspect {
        switch aspect {
        case .free, .original: aspect
        case .ratio(let w, let h): .ratio(h, w)
        }
    }

    // MARK: Helpers

    /// The canvas's sides, at least 1 so every result can be 1 x 1.
    private func bounds(_ canvas: CanvasSize) -> (Int, Int) { (max(canvas.width, 1), max(canvas.height, 1)) }

    private func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int { min(max(value, low), max(low, high)) }

    /// `side * numerator / denominator`, rounded; `denominator` is at least 1.
    private func follow(_ side: Int, _ numerator: Int, _ denominator: Int) -> Int {
        Int((Double(side) * Double(numerator) / Double(max(denominator, 1))).rounded())
    }

    /// `crop` moved and sized to lie inside a `cw` x `ch` canvas, at least 1 x 1.
    private func inside(_ crop: PixelRect, _ cw: Int, _ ch: Int) -> PixelRect {
        let w = clamp(crop.width, 1, cw), h = clamp(crop.height, 1, ch)
        return PixelRect(x: clamp(crop.x, 0, cw - w), y: clamp(crop.y, 0, ch - h), width: w, height: h)
    }

    /// A point inside the canvas; NaN goes to 0.
    private func pinned(_ point: Mask.Point, _ cw: Int, _ ch: Int) -> Mask.Point {
        func pin(_ v: Double, _ high: Int) -> Double { v.isNaN ? 0 : min(max(v, 0), Double(high)) }
        return Mask.Point(x: pin(point.x, cw), y: pin(point.y, ch))
    }

    /// The largest size of `lock`'s ratio inside `maxW` x `maxH`, at least 1 x 1.
    private func largest(_ lock: (w: Int, h: Int), within maxW: Int, _ maxH: Int) -> (w: Int, h: Int) {
        let maxW = max(maxW, 1), maxH = max(maxH, 1)
        if Double(maxW) * Double(lock.h) <= Double(maxH) * Double(lock.w) {
            return (maxW, clamp(follow(maxW, lock.h, lock.w), 1, maxH))
        }
        return (clamp(follow(maxH, lock.w, lock.h), 1, maxW), maxH)
    }
}
