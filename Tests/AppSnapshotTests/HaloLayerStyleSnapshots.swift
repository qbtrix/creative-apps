// HaloLayerStyleSnapshots.swift (layer-styles HY-2): Halo's style panel and Layer menu items. `panel`: on
// `three-layers` with Title selected, Layer Style… opens the panel at Drop Shadow; the sheet's content
// (HaloStyleSheet, SuiteUI's LayerStylePanel with Done) draws over the four Layer menu items as buttons, since the
// menu bar does not render here: Layer Style… live, Copy, Paste and Clear Layer Style disabled with their reasons.
// Writes halo-layer-style-panel-light.png and halo-layer-style-panel-dark.png. macOS only.
import HaloModel
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
}
