// LayerStyleRulesTests.swift (layer-styles LS-1 written disabled, LS-5 on, with the clamp, reach,
// one-per-kind and paint-order cases): ranges, defaults, one per kind, paint order, reach, presets, JSON.
import CoreRaster
import Testing
import SuiteImaging
import SuiteKernel

func shadowStyle(angle: Double = 135, distance: Double = 8, spread: Double = 0, size: Double = 12) -> LayerStyle {
    let shadow = StyleShadow(color: .black, angle: angle, distance: distance, spread: spread, size: size)
    return LayerStyle(effects: [StyleEffect(kind: .dropShadow, isEnabled: true, blendMode: .multiply, opacity: 0.35,
                                            parameters: .shadow(shadow))], fillOpacity: 1)
}

func strokeStyle(_ position: StrokePosition, size: Double) -> LayerStyle {
    LayerStyle(effects: [StyleEffect(kind: .stroke, isEnabled: true, blendMode: .normal, opacity: 1,
                                     parameters: .stroke(StyleStroke(fill: .solid(.black), size: size, position: position)))],
               fillOpacity: 1)
}

func shadowOf(_ style: LayerStyle) -> StyleShadow? {
    guard case .shadow(let shadow)? = style.effect(.dropShadow)?.parameters else { return nil }
    return shadow
}

@Suite struct LayerStyleRulesTests {
    /// Each kind's defaults are its own kind, turned on and well formed; the shadow's is 135°, 8 px, size 12.
    @Test func defaultsMatchTheirKind() {
        for kind in StyleKind.allCases {
            let effect = StyleRules.defaults(kind)
            #expect(effect.kind == kind && effect.isEnabled && StyleRules.check(LayerStyle(effects: [effect], fillOpacity: 1)) == nil)
        }
        #expect(StyleRules.defaults(.dropShadow) == shadowStyle().effects.first)
    }
    /// The five presets round-trip through JSON.
    @Test func presetsRoundTrip() throws {
        #expect(StyleRules.presets.map(\.name) == ["Soft Shadow", "Lifted", "Outline", "Neon", "Embossed"])
        for preset in StyleRules.presets {
            #expect(StyleRules.check(preset.style) == nil && StyleRules.clamped(preset.style) == preset.style, "\(preset.name)")
            #expect(try StyleRules.style(json: StyleRules.json(preset.style)) == preset.style, "\(preset.name)")
        }
    }
    /// Angles wrap into [0, 360): 400° is 40°, -90° is 270°.
    @Test func angleWraps() throws {
        #expect(shadowOf(StyleRules.clamped(shadowStyle(angle: 400)))?.angle == 40)
        #expect(shadowOf(StyleRules.clamped(shadowStyle(angle: -90)))?.angle == 270)
        #expect(shadowOf(try StyleRules.setting(.object(["angle": .number(760)]), on: .dropShadow, in: shadowStyle()))?.angle == 40)
    }
    /// Size clamps to 0...250 with 250 itself kept; a stroke is at least 1 px; opacity 0...1.
    @Test func sizeClamps() throws {
        #expect(shadowOf(StyleRules.clamped(shadowStyle(size: 300)))?.size == 250)
        #expect(shadowOf(StyleRules.clamped(shadowStyle(size: 250)))?.size == 250)
        #expect(shadowOf(StyleRules.clamped(shadowStyle(distance: -5)))?.distance == 0)
        #expect(StyleRules.clamped(strokeStyle(.outside, size: 0)) == strokeStyle(.outside, size: 1))
        let set = try StyleRules.setting(.object(["size": .number(300), "opacity": .number(2)]), on: .dropShadow, in: shadowStyle())
        #expect(shadowOf(set)?.size == 250 && set.effect(.dropShadow)?.opacity == 1)
    }
    /// A NaN or infinite value is refused, never clamped: `setting` and decoding throw, `check` names it.
    @Test func nonFiniteRefused() {
        for bad in [Double.nan, .infinity] {
            #expect(throws: CatalogError.self) {
                try StyleRules.setting(.object(["size": .number(bad)]), on: .dropShadow, in: shadowStyle())
            }
            var json = StyleRules.json(shadowStyle())
            if case .object(var root) = json { root["fillOpacity"] = .number(bad); json = .object(root) }
            #expect(throws: CatalogError.self) { try StyleRules.style(json: json) }
        }
        #expect(StyleRules.check(shadowStyle(size: .nan))?.contains("dropShadow") == true)
    }
    /// Adding a kind the style has replaces it with its defaults: never two shadows.
    @Test func addingReplacesTheSameKind() throws {
        let moved = try StyleRules.setting(.object(["distance": .number(20)]), on: .dropShadow, in: shadowStyle())
        let added = StyleRules.adding(.dropShadow, to: moved)
        #expect(added.effects == [StyleRules.defaults(.dropShadow)])
        #expect(StyleRules.adding(.stroke, to: added).effects.map(\.kind) == [.dropShadow, .stroke])
    }
    /// Decoding two strokes keeps the first; `check` names the second.
    @Test func decodingKeepsOnePerKind() throws {
        let first = strokeStyle(.outside, size: 3), second = strokeStyle(.inside, size: 9)
        let two = LayerStyle(effects: first.effects + second.effects, fillOpacity: 1)
        #expect(StyleRules.check(two)?.contains("stroke") == true)
        #expect(try StyleRules.style(json: StyleRules.json(two)) == first)
    }
    /// Reach: shadow distance + size·(1 + spread), glow size·(1 + spread), outside stroke size, centre half; up.
    @Test func reachCoversWhatDrawsOutside() throws {
        #expect(StyleRules.reach(shadowStyle()) == 20)
        #expect(StyleRules.reach(shadowStyle(spread: 0.5)) == 26)
        #expect(StyleRules.reach(StyleRules.adding(.outerGlow, to: .none)) == 12)
        #expect(StyleRules.reach(strokeStyle(.outside, size: 3)) == 3)
        #expect(StyleRules.reach(strokeStyle(.center, size: 3)) == 2)
        #expect(StyleRules.reach(strokeStyle(.inside, size: 3)) == 0)
        var off = shadowStyle(); off.effects[0].isEnabled = false
        #expect(StyleRules.reach(off) == 0 && StyleRules.reach(.none) == 0)
    }
    /// Under the layer the drop shadow first; the stroke last; every kind once.
    @Test func paintOrder() {
        #expect(StyleRules.paintOrder == [.dropShadow, .outerGlow, .gradientOverlay, .colorOverlay, .innerGlow,
                                          .innerShadow, .bevel, .stroke])
        #expect(Set(StyleRules.paintOrder) == Set(StyleKind.allCases) && StyleRules.paintOrder.count == StyleKind.allCases.count)
    }
}
