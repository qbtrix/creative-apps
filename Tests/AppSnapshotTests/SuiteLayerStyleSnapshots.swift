// SuiteLayerStyleSnapshots.swift (layer-styles LS-4): LayerStylePanel (LS-3) on the panel colour, as the gallery's
// `layer-style` page hosts it, in Light and Dark. Writes suiteui-layer-style-{light,dark}.png (no style: the eight
// switches off, Drop Shadow's defaults shown disabled), suiteui-layer-style-drop-shadow-{light,dark}.png (Drop Shadow
// on, its rows enabled), suiteui-layer-style-stroke-gradient-{light,dark}.png (an outside 4 px stroke on a linear
// gradient: the shared GradientEditor under the row) and suiteui-layer-style-no-layer-{light,dark}.png (no layer:
// every control disabled with StyleRules.noLayerHelp under them). The presets menu shows disabled until LS-5 fills
// StyleRules.presets. macOS only.
import SuiteImaging
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteLayerStyleSnapshots {
    @Test func layerStylePanelStates() throws {
        let shadow = StyleRules.defaults(.dropShadow)
        let gradient = GradientRules.converted(.solid(.black), to: .linear, in: StyleEdit.unit)
        var stroke = StyleRules.defaults(.stroke)
        stroke.parameters = .stroke(StyleStroke(fill: gradient, size: 4, position: .outside))
        let states: [(suffix: String, sample: LayerStyleSample)] = [
            ("", LayerStyleSample(style: .none, selected: .dropShadow)),
            ("-drop-shadow", LayerStyleSample(style: LayerStyle(effects: [shadow], fillOpacity: 1), selected: .dropShadow)),
            ("-stroke-gradient", LayerStyleSample(style: LayerStyle(effects: [stroke], fillOpacity: 1), selected: .stroke)),
            ("-no-layer", LayerStyleSample(style: nil, selected: .dropShadow)),
        ]
        #expect(StyleEdit.fields(stroke).contains(where: \.isGradient), "the gradient stroke shows no gradient row")
        for (suffix, sample) in states {
            for scheme in [ColorScheme.light, .dark] {
                try snapshot(sample, name: "suiteui-layer-style\(suffix)-\(scheme.name)", scheme: scheme)
            }
        }
    }
}

/// The panel on the panel colour at the gallery page's width.
private struct LayerStyleSample: View {
    let style: LayerStyle?
    let selected: StyleKind

    var body: some View {
        LayerStylePanel(style: style, selected: selected, help: nil) { _ in }
            .frame(width: SuiteSize.inspectorWidth.min + SuiteSize.inspectorWidth.max)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
