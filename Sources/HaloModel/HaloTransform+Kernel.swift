// HaloTransform+Kernel.swift: Halo's selected layer as a SuiteKernel
// TransformTarget (transform HT-1 stubs, HT-5 bodies;
// docs/blueprints/halo/features/transform.md). The box is the layer's rect
// scaled by its sampled scale, centred where its world matrix puts the rect's
// centre at the playhead, turned by its sampled rotation; a negative scale is
// a mirror. `setTransform` writes Scale, Rotation and Position back at the
// playhead through `services.keying` (a key when the track is animated, the
// static value when not), only the rows that change, as one step named
// `name`; writes under one `drag` token fold into that step. The turn keeps
// its winding (370 turned 10 more is 380). A parent's matrix places the
// centre; the size and turn are the layer's own. Flip is refused. The turn
// and scale rules are the kernel's TransformRules; the matrices FlareCore's.
// Linux-safe.
import FlareCore
import SuiteKernel

extension HaloProject: TransformTarget {
    /// The selected layer's box at the playhead, in composition pixels; nil
    /// with no layer selected, a null, or a layer out of its span.
    public var transformSelection: TransformBox? {
        guard let comp = selectedComposition, let layer = selectedLayer, layer.kind != .null,
            layer.isVisible(at: comp.playheadFrame)
        else { return nil }
        let f = comp.playheadFrame, placing = services.placing
        func v(_ p: HaloProperty) -> Double { placing.value(p, of: layer.id, in: comp, at: f) ?? layer.defaultValue(p, in: comp) }
        let b = layer.bounds(in: comp)
        let world = placing.worldMatrix(of: layer.id, in: comp, at: f) ?? .identity
        let c = world.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
        let (sx, sy) = (v(.scaleX), v(.scaleY))
        let (w, h) = (abs(sx) * b.width, abs(sy) * b.height)
        return TransformBox(
            box: Rect(minX: c.x - w / 2, minY: c.y - h / 2, maxX: c.x + w / 2, maxY: c.y + h / 2),
            degrees: v(.rotation), flipX: sx < 0, flipY: sy < 0)
    }

    /// Why nothing can be transformed: no layer selected.
    public var transformHelp: String? {
        selectedLayer == nil ? "Select a layer to transform." : nil
    }

    /// Halo has no mirrored layers yet.
    public var flipHelp: String? { "Flipping isn't in Halo yet." }

    /// Writes `t` to the selected layer's Scale, Rotation and Position at the
    /// playhead, keyed where animated, as one step named `name` (merged with
    /// the steps of the same `drag`). With no layer selected, or a write the
    /// keying refuses, it throws and changes nothing.
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        guard let id = selectedLayerID, let compID = selectedCompositionID else { throw HaloEditError.noLayerSelected }
        let (placing, keying) = (services.placing, services.keying)
        var failure: (any Error)?
        edit(name, control: "halo.viewer.artboard", coalesceKey: drag.map { "\(id).transform.\($0)" }) { doc in
            do {
                guard let i = doc.compositions.firstIndex(where: { $0.id == compID }) else { throw HaloEditError.noComposition }
                let f = doc.compositions[i].playheadFrame
                let writes = try Self.transformWrites(t, of: id, in: doc.compositions[i], at: f, placing: placing)
                for (p, value) in writes { try keying.setValue(value, for: p, of: id, at: f, in: &doc.compositions[i]) }
            } catch {
                failure = error
                throw error
            }
        }
        if let failure { throw failure }
    }

    /// The rows `t` changes on layer `id` at `f` and their new stored values:
    /// scale from the box's size over the rect's, the turn with its winding
    /// kept, and the position that puts the rect's centre at the box's.
    private static func transformWrites(
        _ t: TransformBox, of id: String, in c: HaloComposition, at f: Int, placing: any LayerPlacing
    ) throws -> [(HaloProperty, Double)] {
        guard let layer = c.layers.first(where: { $0.id == id }) else { throw HaloEditError.unknownLayer(id) }
        func v(_ p: HaloProperty) -> Double { placing.value(p, of: id, in: c, at: f) ?? layer.defaultValue(p, in: c) }
        let b = layer.bounds(in: c)
        let turn = v(.rotation) + TransformRules.normalized(t.degrees - v(.rotation))
        let sx = b.width > 0 ? t.box.width / b.width * (t.flipX ? -1 : 1) : v(.scaleX)
        let sy = b.height > 0 ? t.box.height / b.height * (t.flipY ? -1 : 1) : v(.scaleY)
        let parent = layer.parentID.flatMap { placing.worldMatrix(of: $0, in: c, at: f) } ?? .identity
        let centre = HaloPoint(x: (t.box.minX + t.box.maxX) / 2, y: (t.box.minY + t.box.maxY) / 2)
        let local = (try? parent.inverted())?.apply(centre) ?? centre
        let fromAnchor = HaloMatrix.rotation(degrees: turn) * HaloMatrix.scale(x: sx, y: sy)
            * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
        let offset = fromAnchor.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
        let all: [(HaloProperty, Double)] = [
            (.scaleX, sx), (.scaleY, sy), (.rotation, turn), (.x, local.x - offset.x), (.y, local.y - offset.y),
        ]
        return all.filter { abs($0.1 - v($0.0)) > 1e-9 }
    }
}
