// HaloStroke+Kernel.swift: Halo's project as the kernel's StrokeTarget
// (stroke-style HK-1 stubs, HK-6 bodies), so the nine `stroke.*` commands
// and the stroke editor's gestures run on the selected shape layer. The
// stroke lives in `HaloLayer.stroke`; its trim start, end and offset are
// HaloProperty tracks once HK-5 adds them, sampled at the playhead and keyed
// there when animated, never a second keyframe store. Text, solid and null
// layers take no stroke. Linux-safe.
import SuiteKernel

extension HaloProject: StrokeTarget {
    /// Why the stroke commands can't run on the selection. Stub until HK-6,
    /// which says "Strokes are for shape layers." for any other kind.
    public var strokeHelp: String? { "Strokes aren't built yet." }

    /// nil: Halo trims paths (the trim values key like position).
    public var trimHelp: String? { nil }

    /// The selected shape layer's stroke, its trim sampled at the playhead;
    /// nil for no stroke. Stub: nil until HK-6.
    public var selectedStroke: VectorStroke? { nil }

    /// Sets (nil removes) the selected shape layer's stroke as one step named
    /// `name`; steps under one `drag` fold into one. Stub: throws until HK-6.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        throw StrokeRules.notBuilt
    }
}
