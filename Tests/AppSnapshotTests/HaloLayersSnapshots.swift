// HaloLayersSnapshots.swift: HaloViewer with a composition holding three
// layers, so the status bar shows the layer count; and the inspector on the
// three-layers fixture with Title selected: its header (Text, Frames 24–71),
// the "Properties arrive…" line and the Layers list still shown. Light and
// Dark. Writes halo-layers-*.png and halo-inspector-layer-selected-*.png.
// macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloLayersSnapshots {
    @Test func layers() throws {
        var project = HaloProject()
        project.newComposition()
        project.newLayer(.solid)
        project.newLayer(.shape)
        project.newLayer(.text)
        try snapshot(HaloViewer(model: project), name: "halo-layers-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-layers-dark", scheme: .dark)
    }

    @Test func inspectorLayerSelected() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        project.selectLayer("comp-1-layer-4")
        #expect(project.selectedLayerHeader == HaloLayerHeader(name: "Title", kind: "Text", frames: "Frames 24–71", parent: nil))
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloCompositionInspector(model: project)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "halo-inspector-layer-selected-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
