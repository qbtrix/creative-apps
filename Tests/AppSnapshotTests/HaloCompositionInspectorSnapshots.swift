// HaloCompositionInspectorSnapshots.swift: Halo's composition inspector in the
// Pro density layout for a 1920 × 1080, 30 fps, 10 s composition with two
// layers: the InspectorHeader with the Model's detail lines, the read-only
// Composition rows, then the layer list under Layers; and a composition with no
// layers, whose Layers section shows the one-line "No layers yet" hint. Light
// and Dark. Writes halo-comp-inspector-{light,dark}.png and
// halo-comp-inspector-empty-{light,dark}.png. macOS only.
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
        // No layer selected, so the composition's own rows show.
        var document = project.document
        document.selectedLayerID = nil
        let shown = HaloProject(services: .live, document: document)
        try snapshots(shown, name: "halo-comp-inspector")
    }

    /// A composition with no layers: the Layers section says so in one line.
    @Test func emptyCompositionInspector() throws {
        var project = HaloProject()
        project.newComposition()
        #expect(project.selectedComposition?.layers.isEmpty == true)
        try snapshots(project, name: "halo-comp-inspector-empty")
    }

    /// The inspector in its column on the panel, as `<name>-light.png` and `<name>-dark.png`.
    private func snapshots(_ model: HaloProject, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloCompositionInspector(model: model)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
