// PhotoSample+Kernel.swift: Photo's eyedropper as SuiteKernel's SampleTarget
// (eyedropper PE-1 stubs, PE-6 bodies), so `color.sample` and the Eyedropper
// tool read the same colour: the composite a person sees, in canvas pixels,
// the mean of the tool's `SampleSize` square. Picking is tool state, not a
// document edit, so it is never an undo step. The square's size is the
// tool's own option (`setSampleSize`). Which press picks and when the loupe
// shows (eyedropper PE-3) are decided here too, so the window only routes.
// Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: SampleTarget {
    /// Why nothing can be sampled now; nil with an image open.
    public var sampleHelp: String? { canvas == nil ? "Open an image first." : nil }

    /// The colour of the composite at `point` (canvas pixels), the mean of
    /// the `size` square centred on it; nil outside the image or on empty
    /// canvas. PE-1 stub: nil until PE-6 reads the composite.
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        nil
    }

    /// Samples the composite at `point` with the tool's `sampleSize` and makes
    /// it the brush colour, with no undo step. PE-1 stub: refuses until PE-6.
    public mutating func pickBrushColor(at point: Point) throws {
        throw PhotoRefusal(sampleHelp ?? "Not built yet (PE-6).")
    }

    /// Sets the square the eyedropper reads.
    public mutating func setSampleSize(_ size: SampleSize) {
        sampleSize = size
    }

    /// Whether the canvas shows the Eyedropper's loupe at the pointer (PE-3).
    public var showsSampleLoupe: Bool { canvas != nil && tool == .eyedropper }

    /// Whether a canvas press with `modifiers` held picks a colour instead of
    /// drawing (PE-3): any press with the Eyedropper, or one with the Brush and
    /// Option; never with no image or while Free Transform is under way.
    public func pressPicksColor(modifiers: DragModifiers) -> Bool {
        guard canvas != nil, transformDraft == nil else { return false }
        return tool == .eyedropper || (tool == .brush && modifiers.contains(.option))
    }
}
