// SuiteLayerStyleSnapshots.swift (layer-styles LS-4): LayerStylePanel (LS-3) on the panel colour, as the gallery's
// `layer-style` page hosts it, in Light and Dark. Writes suiteui-layer-style-{light,dark}.png (the Lifted preset,
// Drop Shadow's rows), -neon (the Neon preset, Stroke's rows), -none (no style: every switch off, Drop Shadow's rows
// disabled with their reason) and -no-layer (no layer: everything disabled, the host's reason under the rows).
// macOS only.
import SuiteImaging
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteLayerStyleSnapshots {
    static func preset(_ name: String) -> LayerStyle? { StyleRules.presets.first { $0.name == name }?.style }

    @Test func layerStylePanelStates() throws {
        let lifted = try #require(Self.preset("Lifted"), "no Lifted preset")
        let neon = try #require(Self.preset("Neon"), "no Neon preset")
        let states: [(suffix: String, sample: LayerStyleSample)] = [
            ("", LayerStyleSample(style: lifted, selected: .dropShadow)),
            ("-neon", LayerStyleSample(style: neon, selected: .stroke)),
            ("-none", LayerStyleSample(style: LayerStyle.none, selected: .dropShadow)),
            ("-no-layer", LayerStyleSample(style: nil, selected: .dropShadow, help: StyleRules.noLayerHelp)),
        ]
        #expect(GalleryLayerStyle.summary(neon) == "outerGlow, innerGlow, stroke", "the Neon state isn't a glow pair and a stroke")
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
    var help: String?

    var body: some View {
        LayerStylePanel(style: style, selected: selected, help: help) { _ in }
            .frame(minWidth: SuiteSize.inspectorWidth.ideal)
            .background(SuiteColor.panel)
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
