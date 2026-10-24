// PhotoRetouchMarks.swift: what the canvas shows while a retouch tool drags
// (fill-heal FH-4). A Remove drag keeps the points it passed, a quarter of
// the brush apart, so the overlay can outline the area it will fill on
// release (FH-8 runs the fill); like the Gradient's line, the drag changes
// nothing else (`dragShowsLineOnly`), so the window keeps its later samples
// off the panels. Spot heal and remove show the brush ring
// (`brushCursorDiameter`). Runs on Linux and macOS.
import CoreRaster

extension PhotoWorkspace {
    /// The Remove drag's points, from the press, in canvas pixels, for the
    /// canvas overlay; nil with no Remove drag or one that hasn't moved.
    public var removeStroke: [Mask.Point]? {
        guard let stroke, stroke.tool == .remove, stroke.path.count > 1 else { return nil }
        return stroke.path
    }

    /// Adds `end` to a Remove drag's path once it is a quarter of the brush
    /// (at least a pixel) from the last point kept.
    func trace(_ stroke: inout PhotoStroke, to end: Mask.Point) {
        let last = stroke.path.last ?? stroke.start
        if stroke.path.isEmpty { stroke.path = [last] }
        let step = max(1, brushOptions.size / 4)
        let dx = end.x - last.x, dy = end.y - last.y
        if dx * dx + dy * dy >= step * step { stroke.path.append(end) }
    }
}
