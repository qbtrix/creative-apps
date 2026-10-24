// LayerStyleRulesTests.swift (layer-styles LS-1 written disabled, LS-5 turns it on and adds the
// clamp, reach, one-per-kind and paint-order cases): defaults and the JSON codec.
import Testing
import SuiteImaging

func shadowStyle(angle: Double = 135, distance: Double = 8, spread: Double = 0, size: Double = 12) -> LayerStyle {
    let shadow = StyleShadow(color: .black, angle: angle, distance: distance, spread: spread, size: size)
    return LayerStyle(effects: [StyleEffect(kind: .dropShadow, isEnabled: true, blendMode: .multiply, opacity: 0.35,
                                            parameters: .shadow(shadow))], fillOpacity: 1)
}

@Suite(.disabled("waits on LS-5")) struct LayerStyleRulesTests {
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
        for preset in StyleRules.presets { #expect(try StyleRules.style(json: StyleRules.json(preset.style)) == preset.style) }
    }
}
