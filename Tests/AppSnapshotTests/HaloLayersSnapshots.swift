// HaloLayersSnapshots.swift: HaloViewer with a composition holding three
// layers, so the status bar shows the layer count; and the inspector on the
// three-layers fixture with Title selected: its header (Text, Frames 24–71),
// the "Properties arrive…" line and the Layers list still shown: no separators,
// rows on the panel inset, only Title's kind icon in accent. Then the layer
// list alone (HaloLayerList, layer-panel #770) on three-layers as
// `-HaloFixture` builds it (fake services): four rows with Badge selected;
// "Enter a name." under Badge after a blank rename; and the empty text once
// every layer is deleted. Light and Dark. Writes halo-layers-*.png,
// halo-inspector-layer-selected-*.png, halo-layer-list-*.png,
// halo-layer-list-refused-*.png and halo-layer-list-empty-*.png. macOS only.
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
        // The rows' tooltips and VoiceOver values, top first.
        let kinds = try #require(project.selectedComposition).layers.map(\.kind.layerTitle)
        #expect(kinds == ["Text layer", "Shape layer", "Solid layer", "Null layer"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloCompositionInspector(model: project)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "halo-inspector-layer-selected-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// three-layers with fake services, as `-HaloFixture three-layers` opens it, Badge selected.
    private func threeLayers() throws -> (project: HaloProject, badge: String) {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        let badge = try #require(project.selectedComposition?.layers.first { $0.name == "Badge" }).id
        project.selectLayer(badge)
        return (project, badge)
    }

    /// The list alone in a 240 pt column on the panel, Light and Dark.
    private func snapshotList(_ project: HaloProject, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloLayerList(model: project)
                    .frame(width: 240, height: 200, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func layerList() throws {
        let project = try threeLayers().project
        #expect(project.selectedComposition?.layers.map(\.name) == ["Title", "Badge", "Background", "Rig"])
        try snapshotList(project, name: "halo-layer-list")
    }

    @Test func layerListRefused() throws {
        let fixture = try threeLayers()
        let badge = fixture.badge
        var project = fixture.project
        project.renameLayer(badge, to: "")
        #expect(project.refusal == HaloRefusal(control: "halo.layer.row.\(badge)", message: "Enter a name."))
        #expect(project.selectedComposition?.layers.map(\.name) == ["Title", "Badge", "Background", "Rig"])
        try snapshotList(project, name: "halo-layer-list-refused")
    }

    @Test func layerListEmpty() throws {
        var project = try threeLayers().project
        for _ in 0..<4 { project.deleteSelectedLayer() }
        #expect(project.selectedComposition?.layers.isEmpty == true)
        try snapshotList(project, name: "halo-layer-list-empty")
    }
}
