// Live/LiveCrop.swift: the live crop geometry (crop CR-4) over CoreRaster's
// `PixelBuffer.straightenCrop`. A crop's rect is in 0...1 of that upright
// rect (sc) of the photo turned by the crop's angle, so a frame never shows a
// transparent corner. `initial` centers the aspect as large as fits in sc;
// a drag moves the handle's edges, keeps a locked aspect (a corner from the
// opposite corner, the larger change winning; an edge about the center),
// and keeps every side at least 16 px and inside sc; `straightened` keeps
// the rect; `frame` maps the rect to sc's pixels, rounded and kept inside.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct LiveCrop: CropGeometry {
    public static let unavailable: String? = nil
    /// The shortest side a drag leaves, in photo pixels.
    static let minimumSide = 16.0
    public init() {}

    public func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings {
        let a = try Self.clamped(angle), sc = try Self.straighten(photo, a)
        var rect = UnitRect.full
        if aspect != .original, let ratio = aspect.ratio(for: photo) {
            let r = ratio / (sc.width / sc.height)
            rect = r < 1 ? UnitRect(x: (1 - r) / 2, y: 0, width: r, height: 1)
                : UnitRect(x: 0, y: (1 - 1 / r) / 2, width: 1, height: 1 / r)
        }
        return CropSettings(angle: a, rect: rect, aspect: aspect)
    }

    public func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                        photo: PixelSize) throws -> CropSettings {
        guard dx.isFinite, dy.isFinite else { return crop }
        let sc = try Self.straighten(photo, crop.angle)
        let ux = dx / sc.width, uy = dy / sc.height
        let minW = Self.minimumSide / sc.width, minH = Self.minimumSide / sc.height
        var r = crop.rect
        // Width over height in unit space; nil when the aspect is free.
        let lock = crop.aspect == .free ? nil : (crop.aspect == .original ? 1 : crop.aspect.ratio(for: photo).map {
            $0 / (sc.width / sc.height) })
        let sx = Self.side(handle, minus: [.left, .topLeft, .bottomLeft], plus: [.right, .topRight, .bottomRight])
        let sy = Self.side(handle, minus: [.top, .topLeft, .topRight], plus: [.bottom, .bottomLeft, .bottomRight])
        let right = r.x + r.width, bottom = r.y + r.height, cx = r.x + r.width / 2, cy = r.y + r.height / 2
        if handle == .inside {
            r.x = Self.clamp(r.x + ux, 0, 1 - r.width); r.y = Self.clamp(r.y + uy, 0, 1 - r.height)
        } else if let k = lock {
            // Room for the width from the fixed edges (or the center, for the free axis).
            let roomW = sx < 0 ? right : sx > 0 ? 1 - r.x : 2 * min(cx, 1 - cx)
            let roomH = sy < 0 ? bottom : sy > 0 ? 1 - r.y : 2 * min(cy, 1 - cy)
            let byW = r.width + sx * ux, byH = (r.height + sy * uy) * k
            let wanted = sx == 0 ? byH : sy == 0 || abs(byW - r.width) >= abs(byH - r.width) ? byW : byH
            let w = Self.clamp(wanted, max(minW, minH * k), min(roomW, roomH * k)), h = w / k
            r.x = sx < 0 ? right - w : sx > 0 ? r.x : cx - w / 2
            r.y = sy < 0 ? bottom - h : sy > 0 ? r.y : cy - h / 2
            r.width = w; r.height = h
        } else {
            if sx < 0 { r.x = Self.clamp(r.x + ux, 0, right - minW); r.width = right - r.x }
            if sx > 0 { r.width = Self.clamp(r.width + ux, minW, 1 - r.x) }
            if sy < 0 { r.y = Self.clamp(r.y + uy, 0, bottom - minH); r.height = bottom - r.y }
            if sy > 0 { r.height = Self.clamp(r.height + uy, minH, 1 - r.y) }
        }
        return CropSettings(angle: crop.angle, rect: r, aspect: crop.aspect)
    }

    public func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings {
        CropSettings(angle: try Self.clamped(angle), rect: crop.rect, aspect: crop.aspect)
    }

    public func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect {
        let sc = try Self.straighten(photo, crop.angle)
        let r = crop.rect
        guard [r.x, r.y, r.width, r.height].allSatisfy(\.isFinite) else { throw LibraryError.invalid("crop rect") }
        let x = Self.pixel(r.x * sc.width, Int(sc.width) - 1), y = Self.pixel(r.y * sc.height, Int(sc.height) - 1)
        let w = Self.clamp(Self.pixel(r.width * sc.width, Int(sc.width)), 1, Int(sc.width) - x)
        let h = Self.clamp(Self.pixel(r.height * sc.height, Int(sc.height)), 1, Int(sc.height) - y)
        return PixelRect(x: sc.x + x, y: sc.y + y, width: w, height: h)
    }

    /// The photo's straighten crop at `angle`: its origin and size in the turned photo's pixels.
    static func straighten(_ photo: PixelSize, _ angle: Double) throws -> (x: Int, y: Int, width: Double, height: Double) {
        do {
            let sc = try PixelBuffer.straightenCrop(width: photo.width, height: photo.height, degrees: angle)
            return (sc.x, sc.y, Double(sc.width), Double(sc.height))
        } catch let error as RasterError { throw LibraryError.invalid("\(error)") }
    }

    static func clamped(_ angle: Double) throws -> Double {
        guard angle.isFinite else { throw LibraryError.invalid("the crop angle must be finite") }
        return clamp(angle, CropSettings.angleRange.lowerBound, CropSettings.angleRange.upperBound)
    }

    /// -1 when `handle` moves the low edge on this axis, 1 the high one, 0 neither.
    private static func side(_ handle: CropHandle, minus: Set<CropHandle>, plus: Set<CropHandle>) -> Double {
        minus.contains(handle) ? -1 : plus.contains(handle) ? 1 : 0
    }

    /// `value` rounded to a whole pixel in 0...`upper`.
    private static func pixel(_ value: Double, _ upper: Int) -> Int {
        Int(clamp(value.rounded(), 0, Double(max(upper, 0))))
    }

    /// `value` in `low...high`; `high` wins when they cross.
    private static func clamp<T: Comparable>(_ value: T, _ low: T, _ high: T) -> T { min(max(value, low), high) }
}
