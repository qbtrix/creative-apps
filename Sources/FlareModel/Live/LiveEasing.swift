// LiveEasing.swift: the live `KeyframeEasing` (docs/blueprints/flare.md, 6.2, task LM-6). Presets are the editor's
// six `EasingPreset`s; the curve is `EasingCurve.samples`, FlareCore's `Easing.value(at:)` as FlareWorkspace's editor
// draws it; a change is FlareCore's `SetKeyframeEasing`, one undo step, or one step per drag under `coalesceKey`.
// A summary key (no property) sets every track keyed at its frame together. Agrees with `FakeEasing` on the fixtures.
import FlareCore

public struct LiveEasing: KeyframeEasing {
    /// Most points `curve` returns, so a runaway `count` can't exhaust memory.
    public static let maxCurvePoints = 4096

    public init() {}

    public var presets: [EasingPreset] { EasingPreset.allCases }

    public func curve(_ easing: Easing, count: Int) -> [Point] {
        if count == 1 { return [Point(x: 0, y: easing.value(at: 0))] }
        return EasingCurve.samples(of: easing, count: min(count, Self.maxCurvePoints))
    }

    public func setEasing(_ easing: Easing, at key: KeyRef, owner: LayerOwner,
                          coalesceKey: String?, in engine: inout CommandEngine) throws {
        guard case .scene(let sceneID) = owner else { throw CommandError.invalidDocument(FakeProperties.symbolKeys) }
        guard let layer = engine.document.layers(of: owner)?.first(where: { $0.id == key.layerID }) else {
            throw CommandError.layerNotFound(key.layerID)
        }
        let properties = key.property.map { [$0] }
            ?? layer.tracks.filter { $0.value.contains { $0.frame == key.frame } }.keys.sorted()
        guard !properties.isEmpty else { throw CommandError.keyframeNotFound(property: "", frame: key.frame) }
        let commands = properties.map {
            SetKeyframeEasing(sceneID: sceneID, layerID: key.layerID, property: $0, frame: key.frame, easing: easing)
        }
        guard coalesceKey == nil, commands.count > 1 else {
            for command in commands { try engine.perform(command, coalesceKey: coalesceKey) }
            return
        }
        try engine.group("Set Keyframe Easing") { engine in
            for command in commands { try engine.perform(command) }
        }
    }
}
