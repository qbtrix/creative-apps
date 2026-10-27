// HaloStyle+Kernel.swift: Halo's project as SuiteImaging's LayerStyleTarget (layer-styles HY-1, HY-5), so the eleven `style.*` commands run on the selected layer. The style lives in `HaloLayer.style`
// (SuiteImaging's LayerStyle, never a Halo copy); a drop shadow's distance, size and opacity and an outer glow's
// size and opacity are HaloProperty tracks, sampled at the playhead and keyed there when a track exists.
// Linux-safe.
import SuiteImaging
import SuiteKernel

extension HaloProject: LayerStyleTarget {
    /// Why nothing can be styled: no composition is open.
    static let noStyleComposition = "Make or open a composition to style a layer."

    /// Why the style commands can't run: no composition; nil otherwise (no layer is the kernel's own help).
    public var styleHelp: String? { selectedComposition == nil ? Self.noStyleComposition : nil }

    /// The selected layer's style at the playhead, its keyed numbers sampled there; `.none` for an unstyled
    /// layer; nil with no layer selected.
    public var styleSelection: LayerStyle? {
        guard styleHelp == nil, let c = selectedComposition, let layer = selectedLayer else { return nil }
        return layer.sampledStyle(in: c, at: c.playheadFrame) ?? LayerStyle.none
    }

    /// Opens the panel at `kind`'s section, or closes it; not an undo step.
    public mutating func showStylePanel(_ kind: StyleKind?) { stylePanel = kind }

    /// Where a refused style edit shows.
    static let styleControl = "halo.style"

    /// The selected layer's style becomes `style` (nil in the file for `.none`) as one step named `name`; writes
    /// under one `drag` token fold into one step. A keyed number `style` changes from its value at the playhead
    /// becomes a key there. Keys of a removed effect stay, so they come back with it. Throws, changing nothing,
    /// with no layer selected.
    public mutating func setStyle(_ style: LayerStyle, name: String, drag: String?) throws {
        if drag == nil { endCoalescing() }
        let frame = selectedComposition?.playheadFrame ?? 0
        let done = edit(name, control: Self.styleControl, coalesceKey: drag.map { "style.\($0)" }) { doc in
            guard let c = doc.compositions.firstIndex(where: { $0.id == doc.selectedCompositionID }),
                let l = doc.compositions[c].layers.firstIndex(where: { $0.id == doc.selectedLayerID })
            else { throw HaloEditError.noLayerSelected }
            let comp = doc.compositions[c]
            var layer = comp.layers[l]
            let before = layer
            layer.style = style == .none ? nil : style
            for p in layer.styleProperties {
                guard let track = layer.tracks[p.rawValue], track.count >= 2 else { continue }
                let v = layer.styleValue(p)
                if v != HaloKeyRules.value(p, of: before, in: comp, at: frame) {
                    layer.tracks[p.rawValue] = HaloKeyRules.keyed(track, frame: frame, value: min(max(v, p.range.lowerBound), p.range.upperBound))
                }
            }
            doc.compositions[c].layers[l] = layer
        }
        if drag == nil { endCoalescing() }
        guard done else { throw HaloEditError.noLayerSelected }
    }
}

extension HaloLayer {
    /// The style properties this layer shows, in `HaloProperty.styles` order: a drop shadow's three and an outer
    /// glow's two, each only while its effect is on.
    var styleProperties: [HaloProperty] {
        HaloProperty.styles.filter { p in
            guard let kind = p.styleKind else { return false }
            return style?.effect(kind)?.isEnabled == true
        }
    }

    /// The style with each keyed number sampled at `frame`; nil for an unstyled layer.
    func sampledStyle(in c: HaloComposition, at frame: Int) -> LayerStyle? {
        guard style != nil else { return nil }
        var sampled = self
        for p in styleProperties { sampled.setStyleValue(HaloKeyRules.value(p, of: self, in: c, at: frame), p) }
        return sampled.style
    }

    /// A style property's value with no track: the style's own value when it has that effect, else 0.
    func styleValue(_ property: HaloProperty) -> Double {
        guard let kind = property.styleKind, let effect = style?.effect(kind) else { return 0 }
        switch (property, effect.parameters) {
        case (.shadowOpacity, _), (.glowOpacity, _): return effect.opacity
        case (.shadowDistance, .shadow(let s)): return s.distance
        case (.shadowSize, .shadow(let s)): return s.size
        case (.glowSize, .glow(let g)): return g.size
        default: return 0
        }
    }

    /// Writes `v` into the style's effect for `property`; nothing when the layer has no such effect.
    mutating func setStyleValue(_ v: Double, _ property: HaloProperty) {
        guard let kind = property.styleKind, var s = style, let i = s.effects.firstIndex(where: { $0.kind == kind })
        else { return }
        switch (property, s.effects[i].parameters) {
        case (.shadowOpacity, _), (.glowOpacity, _): s.effects[i].opacity = v
        case (.shadowDistance, .shadow(var p)): p.distance = v; s.effects[i].parameters = .shadow(p)
        case (.shadowSize, .shadow(var p)): p.size = v; s.effects[i].parameters = .shadow(p)
        case (.glowSize, .glow(var p)): p.size = v; s.effects[i].parameters = .glow(p)
        default: return
        }
        style = s
    }
}

extension HaloProperty {
    /// The effect a style property belongs to; nil for the transform properties.
    var styleKind: StyleKind? {
        switch self {
        case .shadowDistance, .shadowSize, .shadowOpacity: .dropShadow
        case .glowSize, .glowOpacity: .outerGlow
        default: nil
        }
    }
}
