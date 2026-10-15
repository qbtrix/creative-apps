// Live/HaloFileValidation.swift: the content checks LiveProjectFiles runs on
// open (#209), and the counter raising that keeps a new id from reusing one
// in the file. Each check is a rule the app already keeps while editing, so
// it reuses W0's constants (CompositionSettings, NameKey) and rules rather
// than restating them. FakeProjectFiles skips this on purpose. Linux-safe.

/// Checks an opened project's contents and raises its id counters.
enum HaloFileValidation {
    /// Throws `HaloFileError.damaged(reason)` for the first broken rule; the
    /// reason names the item ("two compositions share the id comp-1").
    static func check(_ state: HaloDocumentState) throws {
        var compIDs: Set<String> = []
        var names: [String: String] = [:]
        var layerIDs: Set<String> = []
        for comp in state.compositions {
            guard compIDs.insert(comp.id).inserted else { throw damaged("two compositions share the id \(comp.id)") }
            if let taken = names[comp.name.nameKey] {
                throw damaged("two compositions are named \"\(taken)\" and \"\(comp.name)\"")
            }
            names[comp.name.nameKey] = comp.name
            try checkSettings(comp)
            for layer in comp.layers {
                guard layerIDs.insert(layer.id).inserted else { throw damaged("two layers share the id \(layer.id)") }
                try checkLayer(layer, in: comp)
            }
        }
        if let id = state.selectedCompositionID, !compIDs.contains(id) {
            throw damaged("the selected composition \(id) isn't in the project")
        }
        if let id = state.selectedLayerID, !layerIDs.contains(id) {
            throw damaged("the selected layer \(id) isn't in the project")
        }
    }

    /// The state with `nextCompositionNumber` past every "comp-N" id and
    /// `nextLayerNumber` past every "…-layer-N" id; counters only go up.
    static func raisingCounters(_ state: HaloDocumentState) -> HaloDocumentState {
        var raised = state
        for comp in state.compositions {
            if comp.id.hasPrefix("comp-"), let n = Int(comp.id.dropFirst("comp-".count)) {
                raised.nextCompositionNumber = max(raised.nextCompositionNumber, after(n))
            }
            for layer in comp.layers {
                let parts = layer.id.split(separator: "-")
                if parts.dropLast().last == "layer", let last = parts.last, let n = Int(last) {
                    raised.nextLayerNumber = max(raised.nextLayerNumber, after(n))
                }
            }
        }
        return raised
    }

    /// Size, rate and duration as `CompositionSettings` allows them.
    private static func checkSettings(_ comp: HaloComposition) throws {
        let sizes = CompositionSettings.sizeRange
        guard sizes.contains(comp.width), sizes.contains(comp.height) else {
            throw damaged("the composition \(comp.name) is \(comp.width) by \(comp.height) pixels")
        }
        guard CompositionSettings.frameRates.contains(comp.framesPerSecond) else {
            throw damaged("the composition \(comp.name) plays at \(comp.framesPerSecond) fps")
        }
        let longest = Int(CompositionSettings.maxDurationSeconds) * comp.framesPerSecond
        guard (1...longest).contains(comp.durationFrames) else {
            throw damaged("the composition \(comp.name) is \(comp.durationFrames) frames long")
        }
    }

    /// Span (the rule `.inPointAfterOut` enforces: in before out), tracks,
    /// finite values and the parent.
    private static func checkLayer(_ layer: HaloLayer, in comp: HaloComposition) throws {
        let name = layer.name
        guard layer.inFrame < layer.outFrame else {
            throw damaged("the layer \(name) starts at frame \(layer.inFrame), not before its end at frame \(layer.outFrame)")
        }
        for (property, keys) in layer.tracks.sorted(by: { $0.key < $1.key }) {
            var previous: Int?
            for key in keys {
                if let previous, key.frame <= previous {
                    throw damaged("the layer \(name)'s \(property) keys are out of order at frame \(key.frame)")
                }
                guard key.value.isFinite else {
                    throw damaged("the layer \(name)'s \(property) key at frame \(key.frame) isn't a number")
                }
                previous = key.frame
            }
        }
        let color = layer.color
        guard [color.red, color.green, color.blue].allSatisfy(\.isFinite) else {
            throw damaged("the layer \(name)'s color isn't a number")
        }
        if let r = layer.rect, ![r.x, r.y, r.width, r.height].allSatisfy(\.isFinite) {
            throw damaged("the layer \(name)'s rectangle isn't a number")
        }
        guard let parentID = layer.parentID else { return }
        guard comp.layers.contains(where: { $0.id == parentID }) else {
            throw damaged("the layer \(name) follows \(parentID), which isn't in \(comp.name)")
        }
        if FakeLayerPlacing.follows(layer.id, layer.id, in: comp) {
            throw damaged("the layer \(name) follows itself through a parent cycle")
        }
    }

    /// The number after `n`, never past `Int.max`.
    private static func after(_ n: Int) -> Int { n < Int.max ? n + 1 : n }

    private static func damaged(_ reason: String) -> HaloFileError { .damaged(reason) }
}
