// TimelineZoom.swift: the timeline strip's zoom and sideways-scroll rules
// (timeline packet, TL-16; the strip's view is TL-17). Zoom is a factor over
// the host's frameWidth, 1 being fit, kept inside 1...max(1, 64 / frameWidth)
// so a frame never draws wider than 64 pt. Zoom In and Zoom Out step along
// ViewerZoom's stops. The anchor (the frame under the pointer, or the playhead
// for ⌘+ and ⌘−) keeps its screen x across a zoom; during playback the view
// jumps a page when the playhead leaves it. Offsets are content x at the
// view's left edge. Plain math, no SwiftUI (TimelineNavTests).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum TimelineZoom {
    /// The widest a frame draws, in points.
    public static let maxPointsPerFrame: Double = 64

    /// The zoom range for a host's `frameWidth`: fit (1) up to 64 pt per
    /// frame; 1...1 when the host is already that wide or its width isn't a
    /// positive number.
    public static func range(frameWidth: Double) -> ClosedRange<Double> {
        guard frameWidth.isFinite, frameWidth > 0 else { return 1...1 }
        return 1...max(1, maxPointsPerFrame / frameWidth)
    }

    /// `zoom` kept inside `range(frameWidth:)`; fit when it isn't a number.
    public static func clamped(_ zoom: Double, frameWidth: Double) -> Double {
        let r = range(frameWidth: frameWidth)
        guard !zoom.isNaN else { return r.lowerBound }
        return min(max(zoom, r.lowerBound), r.upperBound)
    }

    /// The next ViewerZoom stop above `zoom`, within range.
    public static func zoomedIn(from zoom: Double, frameWidth: Double) -> Double {
        clamped(ViewerZoom.zoomedIn(from: zoom), frameWidth: frameWidth)
    }

    /// The next ViewerZoom stop below `zoom`, within range.
    public static func zoomedOut(from zoom: Double, frameWidth: Double) -> Double {
        clamped(ViewerZoom.zoomedOut(from: zoom), frameWidth: frameWidth)
    }

    /// `frame`'s x in the view at `zoom`, scrolled to `offset`.
    public static func x(ofFrame frame: Int, frameWidth: Double, zoom: Double, offset: Double) -> Double {
        Double(frame) * frameWidth * zoom - offset
    }

    /// The offset after a zoom from `old` to `new` that keeps what sits at
    /// the view x `anchorX` there; `offset` unchanged when either zoom isn't
    /// a positive number.
    public static func anchoredOffset(_ offset: Double, anchorX: Double, from old: Double, to new: Double) -> Double {
        guard old.isFinite, old > 0, new.isFinite, new > 0 else { return offset }
        return (offset + anchorX) * new / old - anchorX
    }

    /// `offset` kept inside the content: frames 0...lastFrame at `zoom` in a
    /// view `viewport` wide; 0 when the content fits.
    public static func clampedOffset(
        _ offset: Double, lastFrame: Int, frameWidth: Double, zoom: Double, viewport: Double
    ) -> Double {
        let content = Double(max(lastFrame, 0)) * frameWidth * zoom
        let top = max(0, content - viewport)
        guard offset.isFinite, top.isFinite else { return 0 }
        return min(max(offset, 0), top)
    }

    /// The follow rule: `offset` while the playhead is in view, otherwise
    /// moved by whole pages (`viewport`) until it is, never below 0.
    public static func followed(
        _ offset: Double, playhead: Int, frameWidth: Double, zoom: Double, viewport: Double
    ) -> Double {
        guard viewport.isFinite, viewport > 0 else { return offset }
        let x = Double(playhead) * frameWidth * zoom
        guard x.isFinite, x < offset || x >= offset + viewport else { return offset }
        return max(0, offset + ((x - offset) / viewport).rounded(.down) * viewport)
    }
}
