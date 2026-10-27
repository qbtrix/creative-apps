// PhotoSample+Kernel.swift: Photo's eyedropper as SuiteKernel's SampleTarget
// (eyedropper PE-1 stubs, PE-6 bodies), so `color.sample` and the Eyedropper
// tool read the same colour: the composite a person sees, in canvas pixels,
// the mean of the tool's `SampleSize` square (SuiteKernel's SampleRules, the
// one mean every sampler uses), rendering only that square. It is Photo's
// only sampling path: an Eyedropper click (`sampleDrag`) and `color.sample`
// both read `sampledColor` (adopt-kernel-eyedropper-photo EP-2). Picking is tool
// state, not a document edit, so it is never an undo step. The square's size is the
// tool's own option (`setSampleSize`). Which press picks and when the loupe
// shows (eyedropper PE-3) are decided here too, so the window only routes.
// Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: SampleTarget {
    /// Why nothing can be sampled now; nil with an image open.
    public var sampleHelp: String? { canvas == nil ? "Open an image first." : nil }

    /// The colour of the composite at `point` (canvas pixels), the mean of
    /// the `size` square centred on the pixel under it (`SampleRules.mean`),
    /// straight-alpha sRGB; nil when that pixel is outside the image, or on
    /// empty canvas. Only the square, clipped to the image, renders: at most
    /// 25 pixels, so never more than one tile, whatever the image's size.
    public func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        guard let canvas, point.x.isFinite, point.y.isFinite, abs(point.x) < 1e7, abs(point.y) < 1e7 else { return nil }
        let column = Int(point.x.rounded(.down)), row = Int(point.y.rounded(.down)), half = size.rawValue / 2
        let square = PixelRect(x: column - half, y: row - half, width: size.rawValue, height: size.rawValue)
        guard (0..<canvas.width).contains(column), (0..<canvas.height).contains(row),
            let region = square.intersection(canvas.rect), let seen = try? rendered(region),
            let bytes = try? seen.rgba8()
        else { return nil }
        return SampleRules.mean(x: column - region.x, y: row - region.y, size: size) { x, y in
            let at = (y * seen.width + x) * 4
            guard x >= 0, y >= 0, x < seen.width, y < seen.height, at + 3 < bytes.count else { return nil }
            return SampleRGBA(r: bytes[at], g: bytes[at + 1], b: bytes[at + 2], a: bytes[at + 3])
        }
    }

    /// Samples the composite at `point` with the tool's `sampleSize` and makes
    /// it the brush colour, with no undo step. Refuses with no image, and
    /// where there is nothing to sample (outside the image, or a fully
    /// transparent square), leaving the brush as it was.
    public mutating func pickBrushColor(at point: Point) throws {
        if let help = sampleHelp { throw PhotoRefusal(help) }
        guard let picked = sampledColor(at: point, size: sampleSize) else {
            throw PhotoRefusal("Nothing to sample there.")
        }
        func channel(_ value: Double) -> UInt8 { UInt8(clamping: SampleRules.byte(value)) }
        setToolOption(.color(red: channel(picked.r), green: channel(picked.g), blue: channel(picked.b)))
    }

    /// One Eyedropper drag event at `point` (canvas pixels): the same pick
    /// as `pickBrushColor`, so a click and `color.sample` read one colour.
    /// Off the image, or with nothing to sample, it changes nothing.
    mutating func sampleDrag(at point: Mask.Point) {
        try? pickBrushColor(at: Point(x: point.x, y: point.y))
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
