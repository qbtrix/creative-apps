// LiveEasing.swift: the live `KeyframeEasing` (docs/blueprints/flare.md, 6.2, task LM-6). Presets are the editor's
// six `EasingPreset`s; the curve is `EaseCurve.samples`, FlareCore's `Easing.value(at:)` as FlareWorkspace's editor
// draws it; a change is FlareCore's `SetKeyframeEasing`, one undo step, or one step per drag under `coalesceKey`.
// A summary key (no property) sets every track keyed at its frame together. Agrees with `FakeEasing` on the fixtures.
// The owner is a scene or a symbol (KY-8): a symbol's layers ease through the same `SetKeyframeEasing(owner:)`, and a
// layer missing from the owner, or an owner that doesn't exist, throws `layerNotFound`.
import FlareCore
import SuiteKernel

public struct LiveEasing: KeyframeEasing {
    /// Most points `curve` returns, so a runaway `count` can't exhaust memory.
    public static let maxCurvePoints = EaseCurve.maxSamples

    public init() {}

    public var presets: [EasingPreset] { EasingPreset.allCases }

    public func curve(_ easing: Easing, count: Int) -> [Point] {
        EaseCurve.samples(of: easing, count: count)
    }

    public func setEasing(_ easing: Easing, at key: KeyRef, owner: LayerOwner,
                          coalesceKey: String?, in engine: inout CommandEngine) throws {
        try key.setEasing(easing, owner: owner, coalesceKey: coalesceKey, in: &engine)
    }
}
