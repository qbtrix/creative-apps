// HaloKeySelection.swift: the picked keys (#428, EZ-2). The EASING list's
// rows are the selected layer's key segments: one per pair of neighbouring
// keys on a track, named after the first. A row picks its segment's first key;
// a timeline diamond picks every key of that lane at its frame, so every
// diamond picks something: a picked key marks the segment it starts, and a
// track's last key the segment it ends. The picked keys are a SuiteKernel
// `Selection` (`keySelection`, AS-h1) used as a set; only this file writes it.
// A pick is never an edit: no history step, no dirty file. ⌫ from the viewer
// or timeline deletes the picked keys as one "Delete Keyframes" step while
// any are picked (`deleteCommand`), else the layer.
// EZ-3: easing the picked keys. A preset is one "Keyframe Easing" step; a
// handle drag is one step until `endCoalescing()` (coalesced per layer); the
// curve and handles the inspector draws come from the first picked segment.
// Linux-safe: no UI imports.
import SuiteKernel

/// One row of the EASING list: a key and the next key on its track.
public struct HaloKeySegment: Identifiable, Sendable, Hashable {
    public var id: HaloKeyRef { key }
    /// The segment's first key; its easing shapes the segment.
    public var key: HaloKeyRef
    /// The next key on the same track.
    public var endFrame: Int
    public var easing: HaloEasing
    public var preset: HaloEasingPreset? { HaloEasingPreset(easing) }
    public var isPicked: Bool
    /// "Position X, frames 0–24": the numbers name frames, not values (#1413).
    public var title: String { "\(key.property.title), frames \(key.frame)–\(endFrame)" }
    /// The row's tooltip: "Eases Position X between its keys at frames 0 and 24.".
    public var help: String {
        "Eases \(key.property.title) between its keys at frames \(key.frame) and \(endFrame)."
    }
    /// The preset's name, or "Custom" for a curve matching none.
    public var easingTitle: String { preset?.title ?? "Custom" }

    public init(key: HaloKeyRef, endFrame: Int, easing: HaloEasing, isPicked: Bool) {
        self.key = key; self.endFrame = endFrame; self.easing = easing; self.isPicked = isPicked
    }
}

/// The two handles of a cubic Bézier easing curve.
public enum HaloEasingHandle: Sendable { case first, second }

extension HaloProject {
    /// The selected layer's segments, in `HaloProperty.allCases` order, then
    /// by frame; empty with no selected layer.
    public var keySegments: [HaloKeySegment] {
        guard let layer = selectedLayer else { return [] }
        var segments: [HaloKeySegment] = []
        for property in HaloProperty.allCases {
            guard let track = layer.tracks[property.rawValue], track.count >= 2 else { continue }
            let sorted = track.sorted { $0.frame < $1.frame }
            for (key, next) in zip(sorted, sorted.dropFirst()) {
                let ref = HaloKeyRef(layerID: layer.id, property: property, frame: key.frame)
                let end = HaloKeyRef(layerID: layer.id, property: property, frame: next.frame)
                let picked = selectedKeys.contains(ref) || (next.frame == sorted.last?.frame && selectedKeys.contains(end))
                segments.append(HaloKeySegment(key: ref, endFrame: next.frame, easing: key.easing, isPicked: picked))
            }
        }
        return segments
    }

    /// The first keys of the picked segments of the selected layer, so stale
    /// and other-layer keys drop out: what easing changes.
    var pickedKeys: Set<HaloKeyRef> {
        Set(keySegments.filter(\.isPicked).map(\.key))
    }

    /// The first picked segment: the one the curve shows.
    public var pickedSegment: HaloKeySegment? {
        keySegments.first(where: \.isPicked)
    }

    /// The preset every picked key shares; nil when they differ, one is
    /// custom, or none is picked.
    public var pickedPreset: HaloEasingPreset? {
        let presets = Set(keySegments.filter(\.isPicked).map(\.preset))
        guard presets.count == 1, let only = presets.first else { return nil }
        return only
    }

    /// Picks `key` from an EASING row. Extending (Shift) toggles it in the
    /// current pick; otherwise it becomes the only pick. A key that starts no
    /// segment (a track's last key, another layer's) changes nothing.
    public mutating func selectKey(_ key: HaloKeyRef, extending: Bool) {
        guard keySegments.contains(where: { $0.key == key }) else { return }
        guard extending else { return keySelection.replace([key]) }
        narrowToPickedKeys()
        keySelection.pick(key, .toggle)
    }

    /// Narrows the pick to `pickedKeys` before a toggle: stale and
    /// other-layer keys drop out, and a picked last key of a track gives way
    /// to the first key of the segment it ends.
    private mutating func narrowToPickedKeys() {
        let alive = pickedKeys
        keySelection.prune { alive.contains($0) }
        for segment in keySegments where segment.isPicked && !keySelection.contains(segment.key) {
            keySelection.pick(segment.key, .extend)
        }
    }

    /// Picks every key of `layerID`'s animated tracks at `frame`, as a
    /// timeline diamond click does. Another layer is selected first, and then
    /// the pick starts over; extending (Shift) on the same layer adds to it.
    public mutating func selectLaneKeys(layerID: String, frame: Int, extending: Bool) {
        var extending = extending
        if layerID != selectedLayerID {
            selectLayer(layerID)
            extending = false
        }
        let keys = segmentKeyList
        let clicked = keys.filter { $0.frame == frame }
        guard extending else { return keySelection.replace(clicked) }
        let alive = Set(keys)
        keySelection.prune { alive.contains($0) }
        for key in clicked { keySelection.pick(key, .extend) }
    }

    /// Every key of the selected layer's segments, first and last alike, in
    /// segment order.
    private var segmentKeyList: [HaloKeyRef] {
        keySegments.flatMap { segment in
            [segment.key, HaloKeyRef(layerID: segment.key.layerID, property: segment.key.property, frame: segment.endFrame)]
        }
    }

    /// `segmentKeyList` as a set.
    private var segmentKeys: Set<HaloKeyRef> { Set(segmentKeyList) }

    /// The picked keys still on the selected layer's animated tracks: what ⌫ deletes.
    public var pickedKeyframes: Set<HaloKeyRef> {
        selectedKeys.intersection(segmentKeys)
    }

    /// What ⌫ sends from the viewer and timeline: Delete Keyframes while any
    /// key is picked, else Delete (the selected layer).
    public var deleteCommand: HaloCommand {
        pickedKeyframes.isEmpty ? .deleteLayer : .deleteKeys
    }

    /// Deletes the picked keys as one "Delete Keyframes" step through the
    /// keying service's key toggle, so a track left with one key goes static
    /// at its value, then picks nothing. Each track's keys go last frame
    /// first, so deleting a whole track leaves its first key's value. Nothing
    /// with nothing picked.
    public mutating func deleteKeys() {
        let keys = pickedKeyframes.sorted {
            $0.property == $1.property ? $0.frame > $1.frame : $0.property.rawValue < $1.property.rawValue
        }
        guard !keys.isEmpty else { return }
        let keying = services.keying
        let deleted = edit("Delete Keyframes", control: "halo.timeline") { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID })
            else { throw HaloEditError.noComposition }
            for key in keys {
                let layer = doc.compositions[c].layers.first { $0.id == key.layerID }
                // A static track keeps one key at 0; toggling a key that's gone would add it back.
                guard layer?.tracks[key.property.rawValue]?.contains(where: { $0.frame == key.frame }) == true
                else { continue }
                try keying.toggleKey(key.property, of: key.layerID, at: key.frame, in: &doc.compositions[c])
            }
        }
        if deleted { keySelection.clear() }
    }

    /// Picks nothing.
    public mutating func clearKeySelection() {
        keySelection.clear()
    }

    // MARK: Easing the picked keys (EZ-3)

    /// Where the picked segment's handles sit; linear and hold read as
    /// (0, 0) and (1, 1). Nil with nothing picked.
    public var easingHandles: (first: HaloPoint, second: HaloPoint)? {
        pickedSegment?.easing.handles
    }

    /// `count` points along the picked segment's curve, x from 0 to 1, y from
    /// FlareCore's `Easing.value(at:)`. Empty with nothing picked.
    public func easingCurve(count: Int) -> [HaloPoint] {
        guard let easing = pickedSegment?.easing, count > 0 else { return [] }
        let last = Double(max(count - 1, 1))
        return (0..<count).map { i in
            let x = Double(i) / last
            return HaloPoint(x: x, y: easing.value(at: x))
        }
    }

    /// Gives every picked key `preset`, as one "Keyframe Easing" step. The
    /// same preset again records nothing (the copy equals the document).
    public mutating func setEasing(_ preset: HaloEasingPreset) {
        applyEasing(preset.easing, coalesceKey: nil)
    }

    /// Gives every picked key `easing`; writes with the same `coalesceKey`
    /// merge into one step until `endCoalescing()`.
    public mutating func setCustomEasing(_ easing: HaloEasing, coalesceKey: String?) {
        applyEasing(easing, coalesceKey: coalesceKey)
    }

    /// Moves one handle of the picked segment's curve to `point` (x clamped to
    /// 0...1, y kept) and gives every picked key that curve. A drag's moves
    /// are one step until `endCoalescing()`. Nothing with nothing picked or a
    /// non-finite point.
    public mutating func moveEasingHandle(_ handle: HaloEasingHandle, to point: HaloPoint) {
        guard let segment = pickedSegment, point.x.isFinite, point.y.isFinite else { return }
        setCustomEasing(segment.easing.movingHandle(handle, to: point), coalesceKey: "\(segment.key.layerID).easing")
    }

    /// One "Keyframe Easing" edit on the picked keys of the selected
    /// composition; the keys and service are copied first, as `edit` mutates.
    private mutating func applyEasing(_ easing: HaloEasing, coalesceKey: String?) {
        let keys = pickedKeys
        let service = services.easing
        edit("Keyframe Easing", control: "halo.easing", coalesceKey: coalesceKey) { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID })
            else { throw HaloEditError.noComposition }
            try service.setEasing(easing, on: keys, in: &doc.compositions[c])
        }
    }
}

extension HaloEasing {
    /// The curve's two handles; linear and hold read as (0, 0) and (1, 1).
    var handles: (first: HaloPoint, second: HaloPoint) {
        switch self {
        case let .cubicBezier(x1, y1, x2, y2): (HaloPoint(x: x1, y: y1), HaloPoint(x: x2, y: y2))
        case .linear, .hold: (HaloPoint(x: 0, y: 0), HaloPoint(x: 1, y: 1))
        }
    }

    /// This curve with `handle` at `point`: x clamped to 0...1, y kept.
    func movingHandle(_ handle: HaloEasingHandle, to point: HaloPoint) -> HaloEasing {
        var (first, second) = handles
        let moved = HaloPoint(x: min(max(point.x, 0), 1), y: point.y)
        switch handle {
        case .first: first = moved
        case .second: second = moved
        }
        return .cubicBezier(x1: first.x, y1: first.y, x2: second.x, y2: second.y)
    }
}
