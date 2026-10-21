// Crop.swift (orientation-crop OC-1 stubs, OC-4 bodies): a crop's aspect and orientation, its
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
    public func ratio(for size: (width: Double, height: Double), orientation: CropOrientation?) -> Double? { nil }
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
    public static func largest(_ aspect: CropAspect, orientation: CropOrientation?, in bounds: Rect) -> Rect { bounds }

    /// `frame` with `handle` dragged to `p`: an edge or corner moves to it while the opposite one
    /// stays (an edge keeps the centre across), holding `aspect` (width over height) when set and
    /// stopping at the bounds; `inside` centres the frame on `p`; `rotate` changes nothing.
    public static func drag(_ frame: Rect, handle: EditorHandle, to p: Point, aspect: Double?, bounds: Rect) -> Rect { frame }

    /// `frame` turned to the other orientation about its centre, filling the same share of `bounds`.
    public static func swapped(_ frame: Rect, in bounds: Rect) -> Rect { frame }

    /// `frame` moved one step (ten when `large`) toward `d`, stopping at the bounds.
    public static func nudged(_ frame: Rect, _ d: Direction, large: Bool, bounds: Rect) -> Rect { frame }
}
