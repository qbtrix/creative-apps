// FlareColorKeys+Kernel.swift: paint keys (timeline-keys TK-7) by the kernel's key rules, and their recording rule.
import FlareCore
import SuiteKernel

extension FlareWorkspace {
    /// A paint property with a key button in the inspector.
    public enum PaintKey: String, CaseIterable, Sendable { case fill, stroke, strokeWidth }

    static let oneShape = "Select one shape first."

    /// Why `key`'s button can't act, or nil while exactly one shape is painted.
    public func paintKeyHelp(_ key: PaintKey) -> String? { onePaintShape == nil ? Self.oneShape : nil }

    /// `key`'s button at the playhead; not animated without exactly one painted shape.
    public func keyState(_ key: PaintKey) -> KeyState {
        guard let (_, i, _, layer) = onePaintShape else { return .notAnimated }
        let state = key == .strokeWidth ? KeyRules.state(layer.tracks[Layer.trackKey(strokeWidthOf: i)] ?? [], at: currentFrame)
            : ColorKeyRules.state(layer.colorTracks[Self.target(key, i).key] ?? [], at: currentFrame)
        return switch state { case .notAnimated: .notAnimated; case .animated: .animated; case .keyedHere: .keyedHere }
    }

    /// Adds `key`'s key at the playhead with the value the shape shows there, or removes the key there.
    public mutating func togglePaintKey(_ key: PaintKey) {
        guard let (a, i, shape, layer) = onePaintShape else { return paintError = Self.oneShape }
        let frame = currentFrame, shown = layer.sampledShape(i, at: Double(frame))
        var old: [Int], new: [Int], write: (Int, Bool) -> PaintKeyWrite, fill: Fill?, stroke = shape.stroke
        if key == .strokeWidth {
            let keys = layer.tracks[Layer.trackKey(strokeWidthOf: i)] ?? [], value = (shown.stroke ?? Self.noStroke).width
            var track = keys
            _ = KeyRules.toggleKey(&track, at: frame, value: value, leaving: .propertyGoesStatic)
            (old, new, write) = (keys.map(\.frame), track.map(\.frame), { .width(a, shape: i, frame: $0, $1 ? value : nil) })
            if track.isEmpty, let last = keys.first(where: { $0.frame != frame }) ?? keys.first { stroke?.width = last.value }
        } else {
            let target = Self.target(key, i), keys = layer.colorTracks[target.key] ?? []
            guard let value = key == .stroke ? (shown.stroke ?? Self.noStroke).color : Self.solid(shown.fill) else {
                return paintError = "Fill keys need a solid fill."
            }
            var track = keys
            _ = ColorKeyRules.toggleKey(&track, at: frame, value: value, leaving: .propertyGoesStatic)
            (old, new, write) = (keys.map(\.frame), track.map(\.frame), { .color(a, target, frame: $0, $1 ? value : nil) })
            if track.isEmpty, let last = keys.first(where: { $0.frame != frame }) ?? keys.first {
                if key == .fill { fill = .solid(last.value) } else { stroke?.color = last.value }
            }
        }
        let writes = old.filter { !new.contains($0) }.map { write($0, false) }
            + (new.contains(frame) && !old.contains(frame) ? [write(frame, true)] : [])
        let properties = services.properties
        paintStep(old.contains(frame) ? "Remove Keyframe" : "Add Keyframe") { engine in
            try properties.keyPaint(writes, coalesceKey: nil, in: &engine)
            if let fill, fill != shape.fill { try properties.setFill(fill, of: [a], in: &engine) }
            if stroke != shape.stroke { try properties.setStroke(stroke, of: [a], in: &engine) }
        }
    }

    /// The recording rule: the frame an edit of a track with `keyCount` keys keys, or nil to set the static value.
    func paintKeyFrame(keyCount: Int) -> Int? { autoKey || keyCount > 0 ? currentFrame : nil }

    /// The painted shapes as they draw at the playhead, their keyed colours and widths sampled in.
    var shownPaintShapes: [FlareShape] {
        paintShapes.map { a, shape in
            guard case .shape(let i) = a.item, let layer = paintLayer(a) else { return shape }
            return layer.sampledShape(i, at: Double(currentFrame))
        }
    }

    /// The fill key for shape `a` when the recording rule keys a fill edit of `color`; nil sets the static fill.
    func fillKey(_ a: StageAddress, _ color: FlareColor) -> PaintKeyWrite? {
        guard case .shape(let i) = a.item, let layer = paintLayer(a) else { return nil }
        let target = TrackTarget.fill(shape: i)
        return paintKeyFrame(keyCount: layer.colorTracks[target.key]?.count ?? 0).map { .color(a, target, frame: $0, color) }
    }

    /// One shape's stroke edit by the recording rule: the static stroke (keeping a keyed part's own value) and the keys.
    func strokeEdit(_ a: StageAddress, _ shape: FlareShape, _ change: (inout Stroke) -> Void) -> (Stroke, [PaintKeyWrite]) {
        var stroke = shape.stroke ?? Self.noStroke
        change(&stroke)
        guard case .shape(let i) = a.item, let layer = paintLayer(a) else { return (stroke, []) }
        let shown = layer.sampledShape(i, at: Double(currentFrame)).stroke ?? Self.noStroke
        var edited = shown, writes: [PaintKeyWrite] = []
        change(&edited)
        let kept = shape.stroke ?? stroke, target = TrackTarget.stroke(shape: i)
        if edited.color != shown.color, let f = paintKeyFrame(keyCount: layer.colorTracks[target.key]?.count ?? 0) {
            (writes, stroke.color) = (writes + [.color(a, target, frame: f, edited.color)], kept.color)
        }
        if edited.width != shown.width,
           let f = paintKeyFrame(keyCount: layer.tracks[Layer.trackKey(strokeWidthOf: i)]?.count ?? 0) {
            (writes, stroke.width) = (writes + [.width(a, shape: i, frame: f, edited.width)], kept.width)
        }
        return (stroke, writes)
    }

    /// The one painted shape: its address, index, shape and layer; nil unless exactly one.
    private var onePaintShape: (StageAddress, Int, FlareShape, Layer)? {
        let found = paintShapes
        guard found.count == 1, let (a, shape) = found.first, case .shape(let i) = a.item,
              let layer = paintLayer(a) else { return nil }
        return (a, i, shape, layer)
    }

    private func paintLayer(_ a: StageAddress) -> Layer? { document?.layers(of: a.owner)?.first { $0.id == a.layerID } }

    private static func target(_ key: PaintKey, _ i: Int) -> TrackTarget { key == .fill ? .fill(shape: i) : .stroke(shape: i) }

    private static func solid(_ fill: Fill) -> FlareColor? { if case .solid(let c) = fill { c } else { nil } }
}
