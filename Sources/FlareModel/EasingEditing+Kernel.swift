// EasingEditing+Kernel.swift: AE-f1 (#1937). A Flare `KeyRef` is SuiteKernel's `KeyRef<String>`, `.all` for the summary
// key, and an `EasingSegment` on a layer is its `Segment<String>`. An easing at the summary key sets every track keyed there.
import FlareCore
import SuiteKernel

extension KeyRef {
    /// The kernel's key: the named property's track, or `.all` for the summary key.
    public var kernel: SuiteKernel.KeyRef<String> {
        SuiteKernel.KeyRef(layerID: layerID, track: property.map { .property($0) } ?? .all, frame: frame)
    }

    public init(_ key: SuiteKernel.KeyRef<String>) { self.init(layerID: key.layerID, property: key.property, frame: key.frame) }

    /// The tracks of `layer` an easing at this key sets: the named one, or every track keyed at the summary key's frame.
    func easedProperties(in layer: Layer) -> [String] {
        guard case .property(let name) = kernel.track else {
            return layer.tracks.filter { $0.value.contains { $0.frame == frame } }.keys.sorted()
        }
        return [name]
    }

    /// Sets `easing` on each track this key names in `owner`'s layer: one undo step, or merged into `coalesceKey`'s
    /// entry. Live and Fake both write through here. A missing layer throws `layerNotFound`, a key on no track
    /// `keyframeNotFound`.
    func setEasing(_ easing: Easing, owner: LayerOwner, coalesceKey: String?, in engine: inout CommandEngine) throws {
        guard let layer = engine.document.layers(of: owner)?.first(where: { $0.id == layerID }) else {
            throw CommandError.layerNotFound(layerID)
        }
        let properties = easedProperties(in: layer)
        guard !properties.isEmpty else { throw CommandError.keyframeNotFound(property: "", frame: frame) }
        func write(_ engine: inout CommandEngine) throws {
            for property in properties {
                try engine.perform(SetKeyframeEasing(owner: owner, layerID: layerID, property: property,
                                                     frame: frame, easing: easing), coalesceKey: coalesceKey)
            }
        }
        if coalesceKey == nil, properties.count > 1 { try engine.group("Set Keyframe Easing", write) } else { try write(&engine) }
    }
}

extension SuiteKernel.KeyRef where Property == String {
    /// The track's property name; nil for `.all`.
    var property: String? { if case .property(let name) = track { name } else { nil } }
}

extension EasingSegment {
    public func segment(on layerID: String, easing: Easing) -> Segment<String> {
        Segment(key: .init(layerID: layerID, track: .property(property), frame: startFrame), endFrame: endFrame, easing: easing)
    }

    public init(_ segment: Segment<String>) {
        self.init(property: segment.key.property ?? "", startFrame: segment.key.frame, endFrame: segment.endFrame)
    }
}
