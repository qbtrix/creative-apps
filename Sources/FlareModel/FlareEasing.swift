// FlareEasing.swift: FlareWorkspace as the easing editor's EasingEditing
// (docs/blueprints/flare-easing-editor.md). Segments come from the selected
// layer's tracks: each keyframe that has a next keyframe on its track. Presets
// and handle moves are FlareCore SetKeyframeEasing commands through `apply`, so
// each is one undo step and a locked layer's refusal lands in `layerError`.
// A handle drag coalesces in the engine under one key per handle and drag;
// `endEasingHandleDrag()` bumps the serial in that key, so the next move starts
// a new step. The stored selection is dropped when the layer selection changes
// (FlareWorkspace.selectedLayerID) and ignored once its keyframes are gone.
// The selected layer is looked up in the edited owner's layers, so inside a
// symbol the editor reads the symbol's own timeline (#643). SetKeyframeEasing
// still names a scene layer, so an easing change inside a symbol is refused.
import FlareCore

extension FlareWorkspace: EasingEditing {
    static let easingInSymbolMessage = "Exit the symbol to change its easing."

    /// The selected layer in the scene or symbol being edited.
    private var easingLayer: Layer? { ownerLayers?.first { $0.id == selectedLayerID } }

    public var easingSegments: [EasingSegment] {
        guard let layer = easingLayer else { return [] }
        return layer.tracks.keys.sorted().flatMap { property in
            let frames = (layer.tracks[property] ?? []).map(\.frame).sorted()
            return zip(frames, frames.dropFirst()).map {
                EasingSegment(property: property, startFrame: $0, endFrame: $1)
            }
        }
    }

    public var selectedEasingSegment: EasingSegment? {
        easingSelection.flatMap { easingSegments.contains($0) ? $0 : nil }
    }

    public var currentEasing: Easing? {
        guard let segment = selectedEasingSegment, let layer = easingLayer else { return nil }
        return layer.tracks[segment.property]?.first { $0.frame == segment.startFrame }?.easing
    }

    public mutating func selectEasingSegment(_ segment: EasingSegment) {
        guard easingSegments.contains(segment) else { return }
        easingSelection = segment
        endEasingHandleDrag()
    }

    public mutating func setEasingPreset(_ preset: EasingPreset) {
        endEasingHandleDrag()
        setEasing(preset.easing, coalesceKey: nil)
    }

    public mutating func moveEasingHandle(_ handle: EasingHandle, to point: Point) {
        guard let segment = selectedEasingSegment, let easing = currentEasing,
              let moved = EasingCurve.moving(easing, handle, to: point)
        else { return }
        let key = "easing/\(selectedLayerID ?? "")/\(segment.property)/\(segment.startFrame)/\(handle.rawValue)/\(easingDragSerial)"
        setEasing(moved, coalesceKey: key)
    }

    public mutating func endEasingHandleDrag() {
        easingDragSerial &+= 1
    }

    public func easingCurveSamples(count: Int) -> [Point] {
        currentEasing.map { EasingCurve.samples(of: $0, count: count) } ?? []
    }

    /// Gives the selected segment's start keyframe `easing` as one undo step,
    /// or as part of the open step when `coalesceKey` matches the last one.
    private mutating func setEasing(_ easing: Easing, coalesceKey: String?) {
        guard editingSymbolID == nil else { return refuse(.refused(Self.easingInSymbolMessage)) }
        guard let sceneID = selectedSceneID, let layerID = selectedLayerID, let segment = selectedEasingSegment
        else { return }
        let command = SetKeyframeEasing(
            sceneID: sceneID, layerID: layerID, property: segment.property, frame: segment.startFrame, easing: easing)
        apply(command, coalesceKey: coalesceKey)
    }
}
