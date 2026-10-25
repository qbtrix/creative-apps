// PhotoAdjust+Kernel.swift (AJ-8): Photo as the suite's AdjustTarget. Kinds and
// looks act on what the inspector edits (`adjustTarget`), as one undo step. A
// filter rewrites only the selected pixel layer, from its own pixels, weighted
// by the selection's coverage, as one step. Looks live in `services.looks`. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel
import SuiteModel

extension PhotoWorkspace: AdjustTarget {
    public var adjustHelp: String? { canvas == nil ? "Open an image first." : nil }

    public var filterHelp: String? {
        guard let layer = selectedLayer, case .pixels = layer.kind, pixels[layer.id] != nil else {
            return "Select an image layer to filter it."
        }
        return nil
    }

    public var currentLook: LookPreset {
        let s = adjustSettings
        return LookPreset(id: "current", name: "Current", tone: s.tone, adjust: s.imaging, kinds: s.kinds)
    }

    public var kinds: [ImagingKind] { adjustSettings.kinds }

    public var looks: any PresetStoring { services.looks }

    public mutating func setKinds(_ k: [ImagingKind], name: String) throws {
        try changeAdjustSettings(name: name) { $0.setKinds(k) }
    }

    public mutating func applyLook(_ l: LookPreset, name: String) throws {
        try changeAdjustSettings(name: name) { $0.apply(l) }
    }

    public mutating func applyFilter(_ f: ImagingFilter, name: String) throws {
        if let why = adjustHelp ?? filterHelp { throw CatalogError.unavailable(id: "filter.\(f.id)", why: why) }
        guard let layer = selectedLayer, let region = bounds(of: layer), let tiled = pixels[layer.id] else { return }
        let done = try FilterRules.apply(f, to: try tiled.flattened(), coverage: nil)
        let (dx, dy) = (layer.offsetX, layer.offsetY)
        editSelection(named: name, in: region, masked: true) { x, y, old in (try? done.pixel(x: x - dx, y: y - dy)) ?? old }
    }

    /// The settings the kinds and looks act on: the selected adjustment layer's, or the image's.
    private var adjustSettings: AdjustmentSettings {
        if case .layer(_, let settings) = adjustTarget { return settings }
        return adjustments
    }

    /// `change` made to `adjustSettings` as one step called `name`; nothing is recorded when it changes nothing.
    private mutating func changeAdjustSettings(name: String, _ change: (inout AdjustmentSettings) -> Void) throws {
        if let why = adjustHelp { throw CatalogError.unavailable(id: name, why: why) }
        var next = adjustSettings
        change(&next)
        guard next != adjustSettings else { return }
        switch adjustTarget {
        case .image:
            record(.adjustments(adjustments), named: name)
            adjustments = next
            touch(.all, adjustmentsOnly: true)
        case .layer(let id, _):
            guard let at = index(of: id) else { return }
            recordLayers(named: name)
            layers[at].kind = .adjustment(next)
            touch(.all)
        }
    }
}
