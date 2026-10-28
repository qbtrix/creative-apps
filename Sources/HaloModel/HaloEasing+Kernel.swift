// HaloEasing+Kernel.swift: AE-h1 (#1937). Halo's key words map onto SuiteKernel's Keys: a `HaloKeyRef` is the
// kernel's `KeyRef<HaloProperty>` on a property's track, a `HaloKeySegment` its `Segment<HaloProperty>`,
// and `HaloKeyState` its `KeyState`. Presets and handle math are the kernel's `EasePreset` and `EaseCurve`, used
// directly (all six presets, the kernel's titles). `HaloKeyRef` stays because it saves a `property`, not a `track`,
// so files load unchanged. Linux-safe.
import SuiteKernel

extension HaloKeyRef {
    /// The kernel's key: this property's track.
    public var kernel: KeyRef<HaloProperty> { KeyRef(layerID: layerID, track: .property(property), frame: frame) }

    /// Halo's key for the kernel's; nil for `.all`, which no Halo row names.
    public init?(_ key: KeyRef<HaloProperty>) {
        guard case .property(let property) = key.track else { return nil }
        self.init(layerID: key.layerID, property: property, frame: key.frame)
    }
}

extension HaloKeySegment {
    /// The kernel's segment: this row's key, end frame and easing.
    public var segment: Segment<HaloProperty> { Segment(key: key.kernel, endFrame: endFrame, easing: easing) }

    /// The row for the kernel's `segment`; nil for a segment on `.all`.
    public init?(_ segment: Segment<HaloProperty>, isPicked: Bool) {
        guard let key = HaloKeyRef(segment.key) else { return nil }
        self.init(key: key, endFrame: segment.endFrame, easing: segment.easing, isPicked: isPicked)
    }
}

extension HaloKeyState {
    /// The kernel's key state, one to one.
    init(_ state: KeyState) {
        switch state {
        case .notAnimated: self = .notAnimated
        case .animated: self = .animated
        case .keyedHere: self = .keyedHere
        }
    }
}
