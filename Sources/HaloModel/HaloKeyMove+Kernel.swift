// HaloKeyMove+Kernel.swift (key-editing KE-1 stubs, KE-4 bodies): moving the
// picked keys, on every layer at once, as an adapter over the kernel's
// `KeyRules.moveKeys`, one "Move Keyframes" step per drag through
// `edit(coalesceKey:)` keyed by the drag's start and `keyDragSerial`. A key
// that would land on an unpicked key, or leave the composition, refuses the
// whole move: nothing moves and `refusal` says where. Linux-safe: no UI imports.
import SuiteKernel

extension HaloProject {
    /// Moves every picked key by `frames` since the last call, on every layer
    /// of the selected composition; calls with the same `dragStart` until
    /// `endKeyDrag()` fold into one "Move Keyframes" step. The pick follows
    /// the keys. Refuses whole, moving nothing, when a key would collide.
    public mutating func moveKeys(by frames: Int, dragStart: Int) {
        guard frames != 0, let comp = selectedComposition else { return }
        let keys = movableKeys(in: comp)
        guard !keys.isEmpty else { return }
        var byLayer: [String: [String: Set<Int>]] = [:]
        for key in keys { byLayer[key.layerID, default: [:]][key.property.rawValue, default: []].insert(key.frame) }
        var refused: (KeyRefusal, String)?
        let range = 0...comp.lastFrame
        let moved = edit("Move Keyframes", control: "halo.timeline", coalesceKey: "keys-\(dragStart)-\(keyDragSerial)") { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID })
            else { throw HaloEditError.noComposition }
            for l in doc.compositions[c].layers.indices {
                let layer = doc.compositions[c].layers[l]
                guard let properties = byLayer[layer.id] else { continue }
                for (name, picked) in properties.sorted(by: { $0.key < $1.key }) {
                    var tracks = [name: layer.tracks[name] ?? []]
                    do throws(KeyRefusal) {
                        try KeyRules.moveKeys(&tracks, picked, by: frames, clampedTo: range)
                    } catch {
                        refused = (error, layer.name)
                        throw error
                    }
                    doc.compositions[c].layers[l].tracks[name] = tracks[name]
                }
            }
        }
        if moved {
            keySelection.replace(keys.map { HaloKeyRef(layerID: $0.layerID, property: $0.property, frame: $0.frame &+ frames) })
        } else if let (why, layerName) = refused {
            refusal = HaloRefusal(control: "halo.timeline", message: Self.message(why, layer: layerName, lastFrame: range.upperBound))
        }
    }

    /// Ends the key drag, so the next move is its own step.
    public mutating func endKeyDrag() {
        endCoalescing()
        keyDragSerial &+= 1
    }

    /// Nil when a picked key can move; otherwise why not.
    public var moveKeysHelp: String? {
        guard let comp = selectedComposition, !movableKeys(in: comp).isEmpty else { return "Select keyframes to move." }
        return nil
    }

    /// The picked keys that are still keys of `comp`, in pick order.
    private func movableKeys(in comp: HaloComposition) -> [HaloKeyRef] {
        let ordered = keySelection.ordered
        guard !ordered.isEmpty else { return [] }
        var frames: [String: [String: Set<Int>]] = [:]
        for layer in comp.layers {
            frames[layer.id] = layer.tracks.mapValues { Set($0.lazy.map(\.frame)) }
        }
        return ordered.filter { frames[$0.layerID]?[$0.property.rawValue]?.contains($0.frame) == true }
    }

    /// The refusal text for a move the kernel refused.
    private static func message(_ why: KeyRefusal, layer: String, lastFrame: Int) -> String {
        switch why {
        case .collides(let frame): "A key is already at frame \(frame) on \(layer)."
        case .pastRange(let frame) where frame < 0: "A key can't move before frame 0."
        case .pastRange: "A key can't move past frame \(lastFrame)."
        }
    }
}
