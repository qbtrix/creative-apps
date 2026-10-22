// PhotoBrush+Kernel.swift: Photo's brush, eraser, clone and heal sampled
// through SuiteKernel's stroke model (adopt-kernel-brush AB-p1). A stroke's
// samples are the kernel's `StrokeSample`; the last four go through a fresh
// `StrokeSmoother` each event, which gives the centripetal Catmull-Rom segment
// they make paintable and flattens it to a quarter pixel; the clone stamp's
// dabs are spaced by `DabSpacer`; the tool options keep their values in
// `BrushSettings` (ToolOptions.swift) and offer `presets`. The capsule, its
// falloff and the max-coverage blend stay in PhotoStroke behind `paint`.
//
// The kernel's smoother mirrors only the far end while it runs, so the first
// segment of a stroke would never come out: the adapter primes it with the
// start mirrored through the first sample, as Photo always drew it. A kernel
// segment keeps its pressure as a range, not which end had which, so the
// pressures come from the window's own samples. Linux-safe.
import CoreRaster
import SuiteKernel

extension Mask.Point {
    /// This point as the kernel's.
    var kernel: Point { Point(x: x, y: y) }

    /// The kernel's `point` as Photo's.
    init(_ point: Point) { self.init(x: point.x, y: point.y) }
}

extension PhotoStroke {
    /// The piece of curve the sample `window` (at most the last four, oldest
    /// first) makes paintable: the segment before the newest sample, or with
    /// `ending` the last one, as points no more than a quarter pixel off it,
    /// with the pressure at its start and end. Nil while the window has too
    /// few samples.
    static func smoothed(_ window: [StrokeSample], ending: Bool) -> (points: [Mask.Point], from: Double, to: Double)? {
        let n = window.count
        let (a, b) = ending ? (n - 2, n - 1) : (n - 3, n - 2)
        guard a >= 0, b < n else { return nil }
        var feed = ending ? Array(window.suffix(3)) : window
        if !ending, n == 3 {
            // The first segment: its start runs on straight, the second sample mirrored through the first.
            let (first, second) = (window[0].point, window[1].point)
            feed.insert(StrokeSample(point: Point(x: 2 * first.x - second.x, y: 2 * first.y - second.y)), at: 0)
        }
        var smoother = StrokeSmoother()
        var segment: StrokeSegment?
        for sample in feed { segment = smoother.add(sample) ?? segment }
        if ending { segment = smoother.finish() }
        guard let segment else { return nil }
        let points = StrokeSmoother.flattened(segment, tolerance: 0.25).map(Mask.Point.init)
        return (points, window[a].pressure, window[b].pressure)
    }
}

extension PhotoWorkspace {
    /// `points` with dabs filled in so no two in a row are more than
    /// `spacing` apart, each pair's evenly and ending on its second point; at
    /// most 10,000 between any two.
    static func dabCenters(_ points: [Mask.Point], spacing: Double) -> [Mask.Point] {
        guard let first = points.first else { return [] }
        var centers = [first]
        for (a, b) in zip(points, points.dropFirst()) {
            let dx = b.x - a.x, dy = b.y - a.y, length = (dx * dx + dy * dy).squareRoot()
            let n = min(max(Int((length / spacing).rounded(.up)), 1), 10_000)
            // The kernel lays the n - 1 between; the pair's end lands on `b` exactly.
            let between = DabSpacer.centers(a.kernel, b.kernel, spacing: length / Double(n), cap: n)
            centers += between.dropFirst().map(Mask.Point.init) + [b]
        }
        return centers
    }
}

extension ToolOptions {
    /// The saved brushes the Tool options offer: each sets size, hardness,
    /// opacity, flow and spacing at once (`ToolOptionEdit.preset`); the color stays.
    public static let presets: [BrushPreset] = [
        BrushPreset(id: "hard-round", name: "Hard Round", settings: BrushSettings()),
        BrushPreset(id: "soft-round", name: "Soft Round", settings: BrushSettings(size: 60, hardness: 0)),
        BrushPreset(id: "fine-detail", name: "Fine Detail", settings: BrushSettings(size: 4, hardness: 80, spacing: 10)),
        BrushPreset(id: "airbrush", name: "Airbrush", settings: BrushSettings(size: 120, hardness: 0, opacity: 30)),
    ]

    /// The preset these settings are, for the Tool options' Preset menu; nil
    /// once any setting differs from every preset's.
    public var preset: BrushPreset? { Self.presets.first { $0.settings == settings } }

    /// `edit` as the kernel's settings edits, opacity floored at Photo's 1%
    /// (a NaN stays NaN, so the kernel ignores it); none for a color or a
    /// gradient edit.
    static func brushEdits(_ edit: ToolOptionEdit) -> [BrushEdit] {
        switch edit {
        case .size(let value): [.size(value)]
        case .hardness(let value): [.hardness(value)]
        case .opacity(let value): [.opacity(value.isNaN ? value : max(value, opacityRange.lowerBound))]
        case .color, .gradient: []
        case .preset(let preset):
            [.size(preset.settings.size), .hardness(preset.settings.hardness), .flow(preset.settings.flow),
             .spacing(preset.settings.spacing)] + brushEdits(.opacity(percent: preset.settings.opacity))
        }
    }
}
