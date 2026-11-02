// HaloStroke+Kernel.swift: Halo's project as the kernel's StrokeTarget
// (stroke-style HK-1 stubs, HK-6 bodies), so the nine `stroke.*` commands
// and the stroke editor's gestures run on the selected shape layer. The
// stroke lives in `HaloLayer.stroke`; its trim start, end and offset are
// HaloProperty tracks (HK-5), sampled at the playhead and keyed there when
// a track exists, never a second keyframe store. Text, solid and null
// layers take no stroke. Linux-safe.
import SuiteKernel

extension HaloProject: StrokeTarget {
    /// Why the stroke commands can't run: the selection isn't a shape layer.
    static let shapeOnlyStrokeHelp = "Strokes are for shape layers."

    /// Why the stroke commands can't run on the selection: "Strokes are for
    /// shape layers." for anything but a shape layer, else nil.
    public var strokeHelp: String? {
        guard selectedComposition != nil, selectedLayer?.kind == .shape else { return Self.shapeOnlyStrokeHelp }
        return nil
    }

    /// nil: Halo trims paths (the trim values key like position).
    public var trimHelp: String? { nil }

    /// The selected shape layer's stroke, its trim sampled at the playhead;
    /// nil for no stroke or no shape layer.
    public var selectedStroke: VectorStroke? {
        guard strokeHelp == nil, let comp = selectedComposition, let layer = selectedLayer else { return nil }
        return HaloOutlines.stroke(of: layer, in: comp, at: comp.playheadFrame)
    }

    /// Sets (nil removes) the selected shape layer's stroke as one step named
    /// `name`; steps under one `drag` fold into one. A trim value with a
    /// track keys at the playhead. Throws off shape layers, changing nothing.
    public mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        if let strokeHelp { throw CatalogError.failed(id: "stroke", message: strokeHelp) }
        let key = drag.flatMap { drag in selectedLayerID.map { CoalesceKey.key("stroke", on: [$0], drag: drag) } }
        let set = edit(name, control: "halo.stroke", coalesceKey: key) { doc in
            let (c, l) = try doc.selectedLayerIndices()
            let comp = doc.compositions[c]
            doc.compositions[c].layers[l].setStroke(stroke, in: comp, at: comp.playheadFrame)
        }
        if !set { throw CatalogError.failed(id: "stroke", message: refusal?.message ?? Self.shapeOnlyStrokeHelp) }
    }

    /// Runs one stroke editor gesture through the project's command catalog;
    /// a refused gesture changes nothing.
    public mutating func runStroke(_ intent: StrokeIntent) {
        let command = intent.command
        _ = try? Self.catalog.run(command.id, params: command.params, on: &self)
    }
}

extension HaloLayer {
    /// Stores `new` (nil clears the stroke and its trim tracks). Each of Trim
    /// Start, End and Offset with a track keys frame `f` when `new` changes
    /// its value there; the stored trim is the value with no track.
    mutating func setStroke(_ new: VectorStroke?, in comp: HaloComposition, at f: Int) {
        guard let new else {
            stroke = nil
            for p in HaloProperty.trims { tracks[p.rawValue] = nil }
            return
        }
        let values: [HaloProperty: Double] = [
            .trimStart: new.trim?.start ?? 0, .trimEnd: new.trim?.end ?? 1, .trimOffset: new.trim?.offset ?? 0,
        ]
        for p in HaloProperty.trims {
            guard let track = tracks[p.rawValue], !track.isEmpty, let v = values[p], v.isFinite,
                  v != HaloKeyRules.value(p, of: self, in: comp, at: f)
            else { continue }
            tracks[p.rawValue] = HaloKeyRules.keyed(track, frame: f, value: v)
        }
        stroke = new
    }
}
