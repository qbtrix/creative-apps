// HaloKeySelection.swift: the keys picked for easing (#428, EZ-2). The
// EASING list's rows are the selected layer's key segments: one per pair of
// neighbouring keys on a track, named after the first. Picking a key, from a
// row or a timeline diamond, writes `selectedKeys`, which only this file
// writes. A pick is never an edit: no history step, no dirty file.
// Linux-safe: no UI imports.

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
    /// "Position X 0 → 24".
    public var title: String { "\(key.property.title) \(key.frame) → \(endFrame)" }
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
                segments.append(
                    HaloKeySegment(
                        key: ref, endFrame: next.frame, easing: key.easing, isPicked: selectedKeys.contains(ref)))
            }
        }
        return segments
    }

    /// The picked keys that still start a segment of the selected layer, so
    /// stale and other-layer keys drop out.
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
        selectedKeys = extending ? pickedKeys.symmetricDifference([key]) : [key]
    }

    /// Picks every segment of `layerID` starting at `frame`, as a timeline
    /// diamond click does. Another layer is selected first, and then the pick
    /// starts over; extending (Shift) on the same layer adds to it.
    public mutating func selectLaneKeys(layerID: String, frame: Int, extending: Bool) {
        var extending = extending
        if layerID != selectedLayerID {
            selectLayer(layerID)
            extending = false
        }
        let starts = Set(keySegments.filter { $0.key.frame == frame }.map(\.key))
        selectedKeys = extending ? pickedKeys.union(starts) : starts
    }

    /// Picks nothing.
    public mutating func clearKeySelection() {
        selectedKeys = []
    }
}
