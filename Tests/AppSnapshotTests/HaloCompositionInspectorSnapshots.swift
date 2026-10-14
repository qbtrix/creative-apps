// HaloCompositionInspectorSnapshots.swift: Halo's composition inspector in the
// Pro density layout for a 1920 × 1080, 30 fps, 10 s composition with two
// layers: the InspectorHeader with the Model's detail lines, the read-only
// Composition rows, then the layer list under Layers. Light and Dark. Writes
// halo-comp-inspector-light.png and halo-comp-inspector-dark.png. macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloCompositionInspectorSnapshots {
    @Test func compositionInspector() throws {
        var project = HaloProject()
        project.newComposition()
        project.newLayer(.solid)
        project.newLayer(.text)
        let comp = try #require(project.selectedComposition)
        #expect(comp.layers.count == 2)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloCompositionInspector(comp: comp, selectedLayerID: project.selectedLayerID)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "halo-comp-inspector-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
