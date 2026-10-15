// LiveShapes+Edit.swift: the live edits (docs/blueprints/flare/features/live-stage.md, task ST-9) and the
// `ShapeBuilding` conformance. Each write is one engine group named by section 2 of real FlareCore commands:
// "Edit Path" is `SetShapePath`; "Move" is `TranslateShape` for a shape and `SetInstanceTransform` for an instance,
// and a text item throws before anything changes; "Delete" is `RemoveShape`, `RemoveTextShape` or `RemoveInstance`,
// highest index first, then `RemoveLayer` for each layer it empties (as the fake); "Duplicate" is `DuplicateLayer`,
// renamed to the fake's "Ball copy", "Ball copy 2" rule; "Paste" is `AddLayer` of the `CommandRegistry.builtIn`
// envelopes `copy` wrote, offset `offset` points right.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

extension LiveShapes {
    /// What `translate` throws for a text item; FlareCore has no text move yet.
    static let textMove = "Text can't be moved yet."
    /// What `paste` throws for data that holds no layer.
    static let nothingToPaste = "Nothing to paste."

    public func setPath(_ path: FlarePath, of item: StageAddress, in engine: inout CommandEngine) throws {
        guard case .shape(let index) = item.item else { throw CommandError.invalidDocument("Only a shape has a path.") }
        let points = path.elements.compactMap { e -> Point? in
            switch e { case .move(let p), .line(let p), .quad(_, let p), .cubic(_, _, let p): p; case .close: nil }
        }
        try engine.group("Edit Path") {
            try $0.perform(SetShapePath(owner: item.owner, layerID: item.layerID, index: index, path: path, points: points))
        }
    }

    public func translate(_ items: [StageAddress], dx: Double, dy: Double, in engine: inout CommandEngine) throws {
        let picked = Self.unique(items)
        if picked.contains(where: { if case .text = $0.item { true } else { false } }) {
            throw CommandError.invalidDocument(Self.textMove)
        }
        try engine.group("Move") { engine in
            for a in picked {
                switch a.item {
                case .shape(let i):
                    try engine.perform(TranslateShape(owner: a.owner, layerID: a.layerID, index: i, dx: dx, dy: dy))
                case .instance(let i):
                    let layer = engine.document.layers(of: a.owner)?.first { $0.id == a.layerID }
                    guard let layer else { throw CommandError.layerNotFound(a.layerID) }
                    guard layer.instances.indices.contains(i) else { throw CommandError.invalidIndex(i) }
                    var transform = layer.instances[i].transform
                    transform.x += dx
                    transform.y += dy
                    try engine.perform(SetInstanceTransform(owner: a.owner, layerID: a.layerID, index: i,
                                                            transform: transform))
                case .text: throw CommandError.invalidDocument(Self.textMove)
                }
            }
        }
    }

    public func delete(_ items: [StageAddress], in engine: inout CommandEngine) throws {
        let order = Self.unique(items).sorted { Self.index($0) > Self.index($1) }
        try engine.group("Delete") { engine in
            for a in order {
                switch a.item {
                case .shape(let i): try engine.perform(RemoveShape(owner: a.owner, layerID: a.layerID, index: i))
                case .text(let i): try engine.perform(RemoveTextShape(owner: a.owner, layerID: a.layerID, index: i))
                case .instance(let i): try engine.perform(RemoveInstance(owner: a.owner, layerID: a.layerID, index: i))
                }
            }
            var removed: [StageAddress] = []
            for a in order where !removed.contains(where: { $0.owner == a.owner && $0.layerID == a.layerID }) {
                guard let layer = engine.document.layers(of: a.owner)?.first(where: { $0.id == a.layerID }),
                      layer.shapes.isEmpty, layer.texts.isEmpty, layer.instances.isEmpty else { continue }
                removed.append(a)
                try engine.perform(RemoveLayer(owner: a.owner, layerID: a.layerID))
            }
        }
    }

    public func duplicate(layers: [String], owner: LayerOwner, in engine: inout CommandEngine) throws -> [String] {
        let originals = (engine.document.layers(of: owner) ?? []).filter { layers.contains($0.id) }.map(\.id)
        var added: [String] = []
        try engine.group("Duplicate") { engine in
            for id in originals {
                let all = engine.document.layers(of: owner) ?? []
                guard let i = all.firstIndex(where: { $0.id == id }) else { throw CommandError.layerNotFound(id) }
                let name = Self.copyName(all[i], in: engine.document).name
                try engine.perform(DuplicateLayer(owner: owner, layerID: id))
                let after = engine.document.layers(of: owner) ?? []
                guard after.indices.contains(i + 1) else { throw CommandError.layerNotFound(id) }
                let copy = after[i + 1]
                if copy.name != name { try engine.perform(RenameLayer(owner: owner, layerID: copy.id, name: name)) }
                added.append(copy.id)
            }
        }
        return added
    }

    public func copy(layers: [String], owner: LayerOwner, from document: Document) throws -> Data {
        let picked = (document.layers(of: owner) ?? []).filter { layers.contains($0.id) }
        return try JSONEncoder().encode(picked.map { try CommandRegistry.builtIn.encode(AddLayer(owner: owner, layer: $0)) })
    }

    public func paste(_ data: Data, owner: LayerOwner, aboveLayerID: String?, offset: Double,
                      in engine: inout CommandEngine) throws -> [String] {
        let envelopes = (try? JSONDecoder().decode([Data].self, from: data)) ?? []
        let pasted = envelopes.compactMap { (try? CommandRegistry.builtIn.decode($0)) as? AddLayer }.map(\.layer)
        guard !pasted.isEmpty, pasted.count == envelopes.count else {
            throw CommandError.invalidDocument(Self.nothingToPaste)
        }
        var index: Int?
        if let aboveLayerID {
            let all = engine.document.layers(of: owner) ?? []
            guard let i = all.firstIndex(where: { $0.id == aboveLayerID }) else {
                throw CommandError.layerNotFound(aboveLayerID)
            }
            guard !all[i].isLocked else { throw CommandError.layerLocked(aboveLayerID) }
            index = i + 1
        }
        var added: [String] = []
        try engine.group("Paste") { engine in
            for layer in pasted {
                var copy = layer
                (copy.name, copy.id) = Self.copyName(layer, in: engine.document)
                let xs = copy.tracks["x"] ?? [Keyframe(frame: 0, value: Layer.standardDefaults["x"] ?? 0)]
                copy.tracks["x"] = xs.map { Keyframe(frame: $0.frame, value: $0.value + offset, easing: $0.easing) }
                try engine.perform(AddLayer(owner: owner, layer: copy, index: index))
                index = index.map { $0 + 1 }
                added.append(copy.id)
            }
        }
        return added
    }

    /// The fake's copy rule: "<base> copy", then "<base> copy 2" and on, the lowest whose name and "<id>-copy-n" id
    /// are both free document-wide, where base is the layer's name less a trailing " copy" or " copy N".
    private static func copyName(_ layer: Layer, in document: Document) -> (name: String, id: String) {
        // One suffix comes off: " copy N" whole, else " copy"; "Ball copy copy 2" keeps "Ball copy".
        var base = layer.name
        if let space = base.lastIndex(of: " "), Int(base[base.index(after: space)...]) != nil,
           base[..<space].hasSuffix(" copy") {
            base = String(base[..<space].dropLast(" copy".count))
        } else if base.hasSuffix(" copy") {
            base.removeLast(" copy".count)
        }
        let taken = Set((document.scenes.flatMap(\.layers) + document.symbols.flatMap(\.layers)).flatMap { [$0.id, $0.name] })
        var n = 1
        while taken.contains(n == 1 ? "\(base) copy" : "\(base) copy \(n)") || taken.contains("\(layer.id)-copy-\(n)") {
            n += 1
        }
        return (n == 1 ? "\(base) copy" : "\(base) copy \(n)", "\(layer.id)-copy-\(n)")
    }
    private static func unique(_ items: [StageAddress]) -> [StageAddress] {
        items.enumerated().filter { !items.prefix($0.offset).contains($0.element) }.map(\.element)
    }
    private static func index(_ a: StageAddress) -> Int {
        switch a.item { case .shape(let i), .text(let i), .instance(let i): i }
    }
}

extension LiveShapes: ShapeBuilding {}
