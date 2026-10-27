// HaloLayerStyleSnapshots.swift (layer-styles HY-2): Halo's style panel and Layer menu items. `panel`: on
// `three-layers` with Title selected, Layer Style… opens the panel at Drop Shadow; the sheet's content
// (HaloStyleSheet, SuiteUI's LayerStylePanel with Done) draws over the four Layer menu items as buttons, since the
// menu bar does not render here: Layer Style… live, Copy, Paste and Clear Layer Style disabled with their reasons.
// Writes halo-layer-style-panel-light.png and halo-layer-style-panel-dark.png. `styleRows` (HY-3): the inspector's
// LAYER STYLE group shows Glow Size and Glow Opacity, each with its stopwatch, only on a layer with an outer glow,
// and TRANSFORM never shows them; writes halo-style-keys-light.png and halo-style-keys-dark.png. macOS only.
import HaloModel
import SuiteImaging
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloLayerStyleSnapshots {
    @Test func panel() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        let title = try #require(project.selectedComposition?.layers.first { $0.name == "Title" })
        project.selectLayer(title.id)
        let items = HaloStyleMenuItems(model: project, run: { _ in })
        #expect(items.ids == HaloProject.styleMenuIDs, "the Layer menu builds its style items by id")
        #expect(items.help("style.panel") == nil, "Layer Style… is live")
        #expect(items.help("style.paste") == "Paste Layer Style: \(HaloProject.nothingCopied)")
        project.runStyleMenu("style.panel")
        #expect(project.stylePanel == .dropShadow, "Layer Style… opens the panel")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                VStack(alignment: .leading, spacing: SuiteSpacing.l) {
                    HaloStyleSheet(model: project, onIntent: { _ in })
                    items
                }
                .padding(SuiteSpacing.xxl)
                .frame(width: 720, height: 560, alignment: .topLeading)
                .background(SuiteColor.panel),
                name: "halo-layer-style-panel-\(scheme.name)", scheme: scheme)
        }
    }

    /// An outer glow 10 px at 75%.
    static let glow = LayerStyle(effects: [
        StyleEffect(kind: .outerGlow, isEnabled: true, blendMode: .screen, opacity: 0.75,
                    parameters: .glow(StyleGlow(color: .white, spread: 0, size: 10))),
    ], fillOpacity: 1)

    @Test func styleRows() throws {
        var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("three-layers")))
        let title = try #require(project.selectedComposition?.layers.first { $0.name == "Title" })
        project.selectLayer(title.id)
        #expect(HaloLayerInspector(model: project).styleRows.isEmpty, "no style rows on a layer without a style")
        try project.setStyle(Self.glow, name: "Add Outer Glow", drag: nil)
        let inspector = HaloLayerInspector(model: project)
        #expect(inspector.styleRows.map(\.property) == [.glowSize, .glowOpacity], "the glow's rows, and only those")
        #expect(inspector.styleRows.first?.text == HaloProperty.glowSize.text(10), "Glow Size reads the style's size")
        #expect(!inspector.transformRows.contains { HaloProperty.styles.contains($0.property) },
                "TRANSFORM keeps to the transform rows")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                inspector
                    .padding(SuiteSpacing.l)
                    .frame(width: 320, height: 720, alignment: .topLeading)
                    .background(SuiteColor.panel),
                name: "halo-style-keys-\(scheme.name)", scheme: scheme)
        }
    }
}
