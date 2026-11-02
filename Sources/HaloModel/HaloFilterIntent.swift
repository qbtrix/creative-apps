// HaloFilterIntent.swift (adjust-everywhere AJ-13): one gesture of the FILTERS inspector section, run on the
// selected layer's list (HaloFilters+Kernel). Add puts a filter on at its starting values (or a kind at its
// neutral start) and leaves an entry already there as it is; a value sets one slider (keys as SuiteUI's
// FilterSheetDraft names them), clamped to its range, and a drag's samples merge into one step by its token;
// hide, remove and move change the list. Each is one step. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteImaging

/// One FILTERS gesture: add an entry by key, set one of its sliders (`drag` names the drag that merges), hide,
/// remove or move it.
public enum HaloFilterIntent: Hashable, Sendable {
    case add(String)
    case value(String, slider: String, Double, drag: String?)
    case hide(String, Bool)
    case remove(String)
    case move(String, to: Int)
}

extension HaloLayerFilter {
    /// The entry's slider values by key ("radius"); empty for a kind.
    public var values: [String: Double] {
        guard case .filter(let f) = step else { return [:] }
        switch f {
        case .gaussianBlur(let r): return ["radius": r]
        case .motionBlur(let d, let l): return ["degrees": d, "distance": l]
        case .sharpen(let a, let r, let t): return ["amount": a, "radius": r, "threshold": t]
        case .reduceNoise(let s, let d): return ["strength": s, "detail": d]
        case .addNoise(let a, _, _): return ["amount": a]
        }
    }

    /// The filter with `slider` at `v`, clamped to its range, the rest kept; nil for a kind, an unknown slider or
    /// a value that isn't finite.
    public func setting(_ slider: String, to v: Double) -> ImagingFilter? {
        guard case .filter(let f) = step, v.isFinite else { return nil }
        func c(_ r: ClosedRange<Double>) -> Double { min(max(v, r.lowerBound), r.upperBound) }
        switch (f, slider) {
        case (.gaussianBlur, "radius"): return .gaussianBlur(radius: c(ImagingFilter.blurRadius))
        case (.motionBlur(_, let l), "degrees"): return .motionBlur(degrees: c(ImagingFilter.motionDegrees), distance: l)
        case (.motionBlur(let d, _), "distance"): return .motionBlur(degrees: d, distance: c(ImagingFilter.motionDistance))
        case (.sharpen(_, let r, let t), "amount"): return .sharpen(amount: c(ImagingFilter.sharpenAmount), radius: r, threshold: t)
        case (.sharpen(let a, _, let t), "radius"): return .sharpen(amount: a, radius: c(ImagingFilter.sharpenRadius), threshold: t)
        case (.sharpen(let a, let r, _), "threshold"): return .sharpen(amount: a, radius: r, threshold: c(ImagingFilter.sharpenThreshold))
        case (.reduceNoise(_, let d), "strength"): return .reduceNoise(strength: c(ImagingFilter.percent), detail: d)
        case (.reduceNoise(let s, _), "detail"): return .reduceNoise(strength: s, detail: c(ImagingFilter.percent))
        case (.addNoise(_, let m, let s), "amount"): return .addNoise(amount: c(ImagingFilter.percent), monochrome: m, seed: s)
        default: return nil
        }
    }
}

extension HaloProject {
    /// The selected layer's list, first run first; empty without one.
    public var layerFilters: [HaloLayerFilter] { selectedLayer?.filters ?? [] }

    /// Runs one FILTERS gesture on the selected layer; a failed step is the project's `refusal`, and while
    /// `adjustHelp` says why nothing runs.
    public mutating func runFilter(_ intent: HaloFilterIntent) {
        switch intent {
        case .add(let id):
            guard !layerFilters.contains(where: { $0.id == id }) else { return }
            if let f = ImagingFilter.defaults(id) { try? setLayerFilter(f, name: f.title) }
            else if let k = Self.startKind(id) { try? setKinds(kinds + [k], name: k.title) }
        case .value(let id, let slider, let v, let drag):
            guard let f = layerFilters.first(where: { $0.id == id })?.setting(slider, to: v) else { return }
            try? setLayerFilter(f, name: f.title, coalesceKey: drag.map { "\(selectedLayerID ?? "").filter.\($0)" })
        case .hide(let id, let hidden): try? setLayerFilterHidden(id, hidden)
        case .remove(let id): try? removeLayerFilter(id)
        case .move(let id, let index): try? moveLayerFilter(id, to: index)
        }
    }

    /// A kind's start: Black & White at neutral weights, Invert.
    static func startKind(_ id: String) -> ImagingKind? {
        switch id {
        case "black-and-white": .blackAndWhite(.neutral)
        case "invert": .invert
        default: nil
        }
    }
}
