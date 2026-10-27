// ViewZoom.swift: the suite's one zoom model (issue #5070, contract rule 20). Every canvas zooms
// through it: SuiteUI's ZoomMath, ViewerZoom and CanvasViewport wrap it in CoreGraphics types, and a
// Model that steps its own zoom (Flare's stage, Library's loupe) uses it directly, since SuiteUI
// doesn't build on Linux.
// - `ZoomSteps`: the 10% to 3200% clamp (a zoom that isn't a number is 100%), Zoom In and Zoom Out
//   over a stop table (the suite's by default; an app may pass its own table, never its own
//   stepping), the snap that lands a pinch near 100% on 100%, the fit scale, the anchor that keeps
//   the document point under the pointer still, and the percent text every zoom pill shows.
// - `ZoomLevel`: fit, 100% or a scale. Fit follows the viewport as it resizes until the user picks
//   another level, so a window that settles keeps its picture fitted.
// - `ZoomKey`: what ⌘= / ⌘+ / ⌘- / ⌘0 / ⌘1 ask for, and the level each one moves to.
// Plain Double math, Linux-safe, tested in ViewZoomTests.

/// The zoom range and the stops Zoom In and Zoom Out step through.
public struct ZoomSteps: Hashable, Sendable {
    /// The stops, smallest first; 1 is 100%.
    public let stops: [Double]
    /// The zoom range, in points per document pixel.
    public let range: ClosedRange<Double>

    /// The suite's range and stops: 10% to 3200%, through 150%.
    public static let suite = ZoomSteps(stops: [0.05, 0.1, 0.25, 1.0 / 3, 0.5, 2.0 / 3, 1, 1.5, 2, 3, 4, 6, 8, 12, 16, 32])

    /// A pinch this close to 100% (either side, as a share) lands on 100%.
    public static let snapShare = 0.04

    /// `stops` within `range` (10% to 3200% unless an app says otherwise).
    public init(stops: [Double], range: ClosedRange<Double> = 0.1...32) {
        self.stops = stops.isEmpty ? [1] : stops
        self.range = range
    }

    /// `zoom` kept inside `range`; 100% when it isn't a number.
    public func clamped(_ zoom: Double) -> Double {
        zoom.isNaN ? 1 : min(max(zoom, range.lowerBound), range.upperBound)
    }

    /// The next stop above `zoom`, or the largest, within `range`; 100% for a zoom that isn't a
    /// positive finite number.
    public func zoomedIn(from zoom: Double) -> Double {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return clamped(stops.first { $0 > zoom * 1.001 } ?? stops[stops.count - 1])
    }

    /// The next stop below `zoom`, or the smallest, within `range`; 100% for a zoom that isn't a
    /// positive finite number.
    public func zoomedOut(from zoom: Double) -> Double {
        guard zoom.isFinite, zoom > 0 else { return 1 }
        return clamped(stops.last { $0 < zoom / 1.001 } ?? stops[0])
    }

    /// `zoom` clamped, and 100% when it is within `snapShare` of it.
    public func snapped(_ zoom: Double) -> Double {
        let z = clamped(zoom)
        return abs(z - 1) < Self.snapShare ? 1 : z
    }

    /// The origin that keeps the document point under `pointer` under it when the zoom goes from
    /// `old` to `new`, all in view points. Both zooms are clamped first, so a zoom held at a range end
    /// leaves the origin where it was. Only their ratio counts.
    public func anchoredOrigin(pointer: Point, origin: Point, from old: Double, to new: Double) -> Point {
        let ratio = clamped(new) / clamped(old)
        return Point(x: pointer.x - (pointer.x - origin.x) * ratio, y: pointer.y - (pointer.y - origin.y) * ratio)
    }

    /// The scale that fits a `width` x `height` document inside a `viewWidth` x `viewHeight` view with
    /// `inset` on every side, never above 100%, 0 when nothing fits. Sides of 0 or less count as 1.
    public static func fitScale(width: Double, height: Double, inWidth viewWidth: Double, height viewHeight: Double, inset: Double) -> Double {
        let roomWidth = viewWidth - 2 * inset, roomHeight = viewHeight - 2 * inset
        guard roomWidth > 0, roomHeight > 0, roomWidth.isFinite, roomHeight.isFinite else { return 0 }
        let scale = min(roomWidth / max(width, 1), roomHeight / max(height, 1), 1)
        return scale.isFinite ? scale : 0
    }

    /// "51%": a zoom as a whole percent; "–" when it isn't a positive finite number. Past a million
    /// percent it reads the cap, never traps.
    public static func percentText(_ zoom: Double) -> String {
        guard zoom.isFinite, zoom > 0 else { return "–" }
        return "\(Int(min(zoom * 100, 1_000_000).rounded()))%"
    }
}

/// A canvas's zoom: fit to the viewport (following it as it resizes), 100%, or a scale (1 is 100%).
public enum ZoomLevel: Hashable, Sendable {
    case fit, actual
    case scale(Double)

    /// `.actual` for a scale of 1, else `.scale(scale)`.
    public init(scale: Double) {
        self = scale == 1 ? .actual : .scale(scale)
    }

    /// The scale this level draws at, for the fit the viewport gives. A fit that isn't a positive
    /// finite number draws at 100%; a bad scale draws at the fit.
    public func scale(fit: Double) -> Double {
        let fitScale = Self.isUsable(fit) ? fit : 1
        switch self {
        case .fit: return fitScale
        case .actual: return 1
        case .scale(let scale): return Self.isUsable(scale) ? scale : fitScale
        }
    }

    /// Whether `scale` can be a zoom: a positive finite number.
    public static func isUsable(_ scale: Double) -> Bool {
        scale.isFinite && scale > 0
    }
}

/// A zoom key: ⌘= or ⌘+ (in), ⌘- (out), ⌘0 (fit) and ⌘1 (100%).
public enum ZoomKey: Hashable, Sendable {
    case zoomIn, zoomOut, fit, actualSize

    /// The zoom `character` asks for with Command down and neither Option nor Control; nil otherwise.
    public init?(_ character: Character, command: Bool, option: Bool = false, control: Bool = false) {
        guard command, !option, !control else { return nil }
        switch character {
        case "=", "+": self = .zoomIn
        case "-": self = .zoomOut
        case "0": self = .fit
        case "1": self = .actualSize
        default: return nil
        }
    }

    /// The level this key moves a canvas drawn at `zoom` to.
    public func level(from zoom: Double, steps: ZoomSteps) -> ZoomLevel {
        switch self {
        case .zoomIn: return ZoomLevel(scale: steps.zoomedIn(from: zoom))
        case .zoomOut: return ZoomLevel(scale: steps.zoomedOut(from: zoom))
        case .fit: return .fit
        case .actualSize: return .actual
        }
    }
}
