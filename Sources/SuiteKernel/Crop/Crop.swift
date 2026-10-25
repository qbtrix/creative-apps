// Crop.swift (orientation-crop OC-a stubs, OC-m bodies): a crop's aspect and orientation, its
// frame, and the rules every app's crop tool shares: the largest frame of an aspect, a handle
// drag kept inside the bounds with the aspect held, swap and nudge. Rects are in the bounds' space.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Which way a locked ratio stands: wider than tall, or taller than wide.
public enum CropOrientation: String, Hashable, Sendable, Codable, CaseIterable { case landscape, portrait }

/// A crop's shape lock: none, the image's own, or width to height (4:5 is `ratio(width: 4, height: 5)`).
/// Its raw values ("Free", "Original", "4:5") are Library's stored keys, and it codes as them.
public enum CropAspect: Hashable, Sendable, Codable, RawRepresentable {
    case free, original, ratio(width: Int, height: Int)

    /// "Free", "Original" or "W:H" with both sides at least 1; nil for anything else.
    public init?(rawValue: String) {
        switch rawValue {
        case "Free": self = .free
        case "Original": self = .original
        default:
            let sides = rawValue.split(separator: ":", omittingEmptySubsequences: false).compactMap { Int($0) }
            guard sides.count == 2, sides[0] >= 1, sides[1] >= 1 else { return nil }
            self = .ratio(width: sides[0], height: sides[1])
        }
    }

    /// The stored key: "Free", "Original" or "W:H".
    public var rawValue: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .ratio(let w, let h): "\(w):\(h)"
        }
    }

    /// Width over height for an image of `size`; nil when free. `orientation` turns a ratio to stand
    /// that way; nil follows the image (taller than wide is portrait), as Library always has.
    public func ratio(for size: (width: Double, height: Double), orientation: CropOrientation?) -> Double? {
        switch self {
        case .free: return nil
        case .original: return size.height > 0 && size.width > 0 ? size.width / size.height : nil
        case .ratio(let w, let h):
            guard w > 0, h > 0 else { return nil }
            let wide = Double(max(w, h)) / Double(min(w, h))
            let stands = orientation ?? (size.height > size.width ? CropOrientation.portrait : .landscape)
            return stands == .portrait ? 1 / wide : wide
        }
    }
}

/// A crop: its rect in the bounds' space (Library's is the unit square of the oriented image) and
/// its straighten angle in degrees.
public struct CropFrame: Hashable, Sendable, Codable {
    public var rect: Rect
    public var angle: Double
    public init(rect: Rect, angle: Double = 0) { (self.rect, self.angle) = (rect, angle) }
}

/// The crop rules every app's crop tool shares. Every result lies inside `bounds`.
public enum CropRules {
    /// The largest frame of `aspect` turned to `orientation` inside `bounds`, centred; `bounds` when free.
    public static func largest(_ aspect: CropAspect, orientation: CropOrientation?, in bounds: Rect) -> Rect {
        guard let k = aspect.ratio(for: (bounds.width, bounds.height), orientation: orientation) else { return bounds }
        return fit(k, scale: 1, about: Point(x: (bounds.minX + bounds.maxX) / 2, y: (bounds.minY + bounds.maxY) / 2), in: bounds)
    }

    /// `frame` with `handle` dragged to `p`: an edge or corner moves to it while the opposite one
    /// stays (an edge keeps the centre across), holding `aspect` (width over height) when set and
    /// stopping at the bounds; `inside` centres the frame on `p`; `rotate` changes nothing.
    public static func drag(_ frame: Rect, handle: EditorHandle, to p: Point, aspect: Double?, bounds: Rect) -> Rect {
        let (sx, sy) = pull(handle)
        if handle == .inside {
            return inside(Rect(minX: p.x - frame.width / 2, minY: p.y - frame.height / 2,
                               maxX: p.x + frame.width / 2, maxY: p.y + frame.height / 2), bounds)
        }
        guard sx != 0 || sy != 0 else { return frame }
        let cx = (frame.minX + frame.maxX) / 2, cy = (frame.minY + frame.maxY) / 2, least = min(bounds.width, bounds.height) / 100
        // The room toward the dragged side from the fixed one, or about the centre on an axis not dragged.
        let roomX = sx > 0 ? bounds.maxX - frame.minX : sx < 0 ? frame.maxX - bounds.minX : 2 * min(cx - bounds.minX, bounds.maxX - cx)
        let roomY = sy > 0 ? bounds.maxY - frame.minY : sy < 0 ? frame.maxY - bounds.minY : 2 * min(cy - bounds.minY, bounds.maxY - cy)
        var w = sx > 0 ? p.x - frame.minX : sx < 0 ? frame.maxX - p.x : frame.width
        var h = sy > 0 ? p.y - frame.minY : sy < 0 ? frame.maxY - p.y : frame.height
        w = max(min(w, roomX), least)
        h = max(min(h, roomY), least)
        if let k = aspect, k > 0, k.isFinite {
            if sx == 0 { w = h * k } else if sy == 0 { h = w / k } else { h = max(h, w / k); w = h * k }
            if w > roomX { (w, h) = (roomX, roomX / k) }
            if h > roomY { (w, h) = (roomY * k, roomY) }
        }
        let minX = sx > 0 ? frame.minX : sx < 0 ? frame.maxX - w : cx - w / 2
        let minY = sy > 0 ? frame.minY : sy < 0 ? frame.maxY - h : cy - h / 2
        return Rect(minX: minX, minY: minY, maxX: minX + w, maxY: minY + h)
    }

    /// `frame` turned to the other orientation about its centre, filling the same share of `bounds`.
    public static func swapped(_ frame: Rect, in bounds: Rect) -> Rect {
        guard frame.width > 0, frame.height > 0, bounds.width > 0, bounds.height > 0 else { return frame }
        let share = max(frame.width / bounds.width, frame.height / bounds.height)
        let centre = Point(x: (frame.minX + frame.maxX) / 2, y: (frame.minY + frame.maxY) / 2)
        return inside(fit(frame.height / frame.width, scale: min(share, 1), about: centre, in: bounds), bounds)
    }

    /// `frame` moved one step (ten when `large`) toward `d`, stopping at the bounds.
    public static func nudged(_ frame: Rect, _ d: Direction, large: Bool, bounds: Rect) -> Rect {
        let step = large ? 10.0 : 1.0
        let (dx, dy) = switch d { case .left: (-step, 0.0); case .right: (step, 0.0); case .up: (0.0, -step); case .down: (0.0, step) }
        return inside(Rect(minX: frame.minX + dx, minY: frame.minY + dy, maxX: frame.maxX + dx, maxY: frame.maxY + dy), bounds)
    }

    /// The largest rect of ratio `k` in `bounds`, scaled by `scale` and centred on `c` (not clamped).
    static func fit(_ k: Double, scale: Double, about c: Point, in bounds: Rect) -> Rect {
        let w = min(bounds.width, bounds.height * k) * scale, h = w / k
        return Rect(minX: c.x - w / 2, minY: c.y - h / 2, maxX: c.x + w / 2, maxY: c.y + h / 2)
    }

    /// `r` moved the least distance that puts it inside `bounds` (it is no bigger than them).
    static func inside(_ r: Rect, _ b: Rect) -> Rect {
        let dx = r.minX < b.minX ? b.minX - r.minX : r.maxX > b.maxX ? b.maxX - r.maxX : 0
        let dy = r.minY < b.minY ? b.minY - r.minY : r.maxY > b.maxY ? b.maxY - r.maxY : 0
        return Rect(minX: r.minX + dx, minY: r.minY + dy, maxX: r.maxX + dx, maxY: r.maxY + dy)
    }

    /// Which way a handle pulls each side: -1 the low side, 1 the high side, 0 neither.
    static func pull(_ h: EditorHandle) -> (Int, Int) {
        switch h {
        case .topLeft: (-1, -1)
        case .top: (0, -1)
        case .topRight: (1, -1)
        case .right: (1, 0)
        case .bottomRight: (1, 1)
        case .bottom: (0, 1)
        case .bottomLeft: (-1, 1)
        case .left: (-1, 0)
        case .inside, .rotate: (0, 0)
        }
    }
}
