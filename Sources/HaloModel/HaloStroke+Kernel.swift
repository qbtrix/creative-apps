// HaloStroke+Kernel.swift: Halo's project as the kernel's StrokeTarget
// (stroke-style HK-1 stubs, HK-6 bodies), so the nine `stroke.*` commands
// and the stroke editor's gestures run on the selected shape layer. The
// stroke lives in `HaloLayer.stroke`; its trim start, end and offset are
// HaloProperty tracks once HK-5 adds them, sampled at the playhead and keyed
// there when animated, never a second keyframe store. Text, solid and null
// layers take no stroke. Linux-safe.
import SuiteKernel

extension HaloProject: StrokeTarget {
    /// Why the stroke commands can't run: the selection isn't a shape layer,
    /// or (until HK-6) the stroke commands aren't built yet.
    static let shapeOnlyStrokeHelp = "Strokes are for shape layers.",
        strokeNotBuiltHelp = "Strokes on shape layers aren't built yet."

    /// Why the stroke commands can't run on the selection. "Strokes are for
    /// shape layers." for anything but a shape layer; on a shape layer the
    /// stub's not-built help, nil once HK-6 lands the bodies.
    public var strokeHelp: String? {
        guard selectedComposition != nil, selectedLayer?.kind == .shape else { return Self.shapeOnlyStrokeHelp }
        return Self.strokeNotBuiltHelp
    }

    /// nil: Halo trims paths (the trim values key like position).
    public var trimHelp: String? { nil }

    /// The selected shape layer's stroke, its trim sampled at the playhead;
    /// nil for no stroke. Stub: nil until HK-6.
    public var selectedStroke: VectorStroke? { nil }

    /// Sets (nil removes) the selected shape layer's stroke as one step named
    /// `name`; steps under one `drag` fold into one. Stub: throws
    /// `StrokeRules.notBuilt` and changes nothing until HK-6.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        throw StrokeRules.notBuilt
    }

    /// Runs one stroke editor gesture through the project's command catalog;
    /// a refused gesture (every one until HK-6 registers the nine specs)
    /// changes nothing.
    public mutating func runStroke(_ intent: StrokeIntent) {
        let command = intent.command
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }
}
